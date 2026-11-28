#!/bin/bash
# =====================================================================
#  Bàn phím điều khiển Mac — phía máy Mac
#  Nhận lệnh từ trang "Đồng hồ chờ" trên điện thoại (qua ntfy.sh)
#
#  Cách dùng:
#   1. Bấm đúp file này (lần đầu: chuột phải > Mở nếu macOS hỏi).
#   2. Cửa sổ Terminal hiện MÃ KẾT NỐI — nhập mã đó vào nút
#      "Kết nối Mac" trên điện thoại, bấm "Thử kết nối" rồi "Lưu".
#   3. Để cửa sổ Terminal mở trong lúc dùng. Đóng cửa sổ = ngắt.
#
#  Phím Phát/Dừng, Bài trước, Bài sau cần quyền Trợ năng cho Terminal:
#   Cài đặt hệ thống > Quyền riêng tư & Bảo mật > Trợ năng > bật Terminal.
#
#  Muốn đổi mã: xóa giá trị trong dòng CODE="..." bên dưới (để CODE="")
#  rồi chạy lại, file sẽ tự tạo mã mới.
# =====================================================================

CODE=""

# ---- Tự tạo mã kết nối lần đầu và ghi vào chính file này ----
SELF="$0"
if [ -z "$CODE" ]; then
  CODE=$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom | head -c 10)
  sed -i '' "s/^CODE=\"\"/CODE=\"$CODE\"/" "$SELF"
fi
TOPIC="dongho-deck-$CODE"
MICFILE="$HOME/.dongho_deck_mic"

# ---- Phím media (giống phím F7/F8/F9 trên bàn phím Mac) ----
#  16 = Phát/Dừng, 19 = Bài sau (F9), 20 = Bài trước (F7)
#  (17/18 là mã next/previous cũ, nhiều trình phát bỏ qua nên không dùng)
media_key() {
  osascript -l JavaScript <<EOF >/dev/null 2>&1
ObjC.import('Cocoa');
ObjC.import('CoreGraphics');
function k(down){
  var ev=\$.NSEvent.otherEventWithTypeLocationModifierFlagsTimestampWindowNumberContextSubtypeData1Data2(
    14, \$.NSMakePoint(0,0), down?0xa00:0xb00, 0, 0, \$(), 8, ($1<<16)|((down?0xa:0xb)<<8), -1);
  \$.CGEventPost(0, ev.CGEvent);
}
k(true); k(false);
EOF
}

# ---- Chuyển bài: Spotify / Apple Music đang phát thì điều khiển thẳng app,
#      còn lại (YouTube, trình duyệt…) dùng phím media F7/F9 ----
skip_track() {  # $1 = "next" hoặc "previous"
  local app st
  for app in Spotify Music; do
    if pgrep -xq "$app"; then
      st=$(osascript -e "tell application \"$app\" to player state as string" 2>/dev/null)
      if [ "$st" = "playing" ]; then
        osascript -e "tell application \"$app\" to $1 track" >/dev/null 2>&1
        echo "   → $app: $1 track"
        return
      fi
    fi
  done
  if [ "$1" = "next" ]; then media_key 19; else media_key 20; fi
}

# ---- Âm lượng ----
vol_change() {
  osascript -e "set v to output volume of (get volume settings)" \
            -e "set volume output volume (v + ($1))" \
            -e "set volume output muted false" >/dev/null 2>&1
}
toggle_mute() {
  osascript -e "set volume output muted (not (output muted of (get volume settings)))" >/dev/null 2>&1
}

# ---- Mic: đưa âm lượng đầu vào về 0 / trả lại mức cũ ----
toggle_mic() {
  local cur
  cur=$(osascript -e "input volume of (get volume settings)" 2>/dev/null)
  if [ -n "$cur" ] && [ "$cur" != "missing value" ] && [ "$cur" -gt 0 ] 2>/dev/null; then
    echo "$cur" >"$MICFILE"
    osascript -e "set volume input volume 0" >/dev/null 2>&1
    echo "   mic: ĐÃ TẮT"
  else
    local old=75
    [ -f "$MICFILE" ] && old=$(cat "$MICFILE")
    osascript -e "set volume input volume $old" >/dev/null 2>&1
    echo "   mic: đã bật ($old)"
  fi
}

# ---- Mở ứng dụng: tự tìm bản mới nhất trong /Applications ----
#  $1 = tên thư mục, $2 = tên app (vd "Adobe Photoshop" → .../Adobe Photoshop 2026.app)
open_app() {
  local app
  app=$(ls -d "/Applications/$1"*/"$2"*.app 2>/dev/null | grep -v "Render Engine" | sort | tail -1)
  if [ -n "$app" ]; then
    open "$app"
  else
    echo "   ✗ Không tìm thấy $2 trong /Applications"
  fi
}

# ---- Thực hiện một lệnh (chỉ chấp nhận các lệnh trong danh sách) ----
run() {
  local a="$1"
  echo "$(date +%H:%M:%S)  $a"
  case "$a" in
    ping)      echo "   ✓ Điện thoại đã kết nối được với máy Mac" ;;
    playpause) media_key 16 ;;
    next)      skip_track next ;;
    prev)      skip_track previous ;;
    mute)      toggle_mute ;;
    voldown)   vol_change -6 ;;
    volup)     vol_change 6 ;;
    mic)       toggle_mic ;;
    sleep)     pmset displaysleepnow ;;
    pr)        open_app "Adobe Premiere Pro" "Adobe Premiere Pro" ;;
    ae)        open_app "Adobe After Effects" "Adobe After Effects" ;;
    ps)        open_app "Adobe Photoshop" "Adobe Photoshop" ;;
    ai)        open_app "Adobe Illustrator" "Adobe Illustrator" ;;
    davinci)   open_app "DaVinci Resolve" "DaVinci Resolve" ;;
    *)         echo "   (bỏ qua lệnh lạ)" ;;
  esac
}

clear
echo "=============================================="
echo "   BÀN PHÍM ĐIỀU KHIỂN MAC"
echo
echo "   Mã kết nối:   $CODE"
echo
echo "   Nhập mã này vào nút “Kết nối Mac” trên điện thoại."
echo "   Giữ cửa sổ này mở. Đóng cửa sổ để ngắt kết nối."
echo "=============================================="
echo

# ---- Lắng nghe lệnh, tự kết nối lại khi rớt mạng ----
while true; do
  echo "Đang chờ lệnh…"
  curl -sN --max-time 0 "https://ntfy.sh/$TOPIC/raw" | while IFS= read -r line; do
    line=$(printf '%s' "$line" | tr -d '\r' | tr -cd 'a-z')
    [ -n "$line" ] && run "$line"
  done
  echo "Mất kết nối — thử lại sau 3 giây…"
  sleep 3
done
