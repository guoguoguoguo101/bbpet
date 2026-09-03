param(
  [Int64]$Hwnd,
  [string]$RectFile = '',
  [switch]$Clear
)
Add-Type -TypeDefinition @"
using System;
using System.IO;
using System.Runtime.InteropServices;
public static class BbPetShape {
  [DllImport("gdi32.dll")]
  public static extern IntPtr CreateRectRgn(int left, int top, int right, int bottom);
  [DllImport("gdi32.dll")]
  public static extern int CombineRgn(IntPtr dest, IntPtr src1, IntPtr src2, int combineMode);
  [DllImport("gdi32.dll")]
  public static extern bool DeleteObject(IntPtr ho);
  [DllImport("user32.dll")]
  public static extern int SetWindowRgn(IntPtr hWnd, IntPtr hRgn, bool bRedraw);
  public static void Apply(long hwnd, string path) {
    IntPtr h = (IntPtr)hwnd;
    string text = File.ReadAllText(path);
    if (string.IsNullOrWhiteSpace(text)) return;
    IntPtr region = IntPtr.Zero;
    foreach (string part in text.Split(new[] { ';' }, StringSplitOptions.RemoveEmptyEntries)) {
      string[] n = part.Split(',');
      if (n.Length < 4) continue;
      int x = int.Parse(n[0]);
      int y = int.Parse(n[1]);
      int w = int.Parse(n[2]);
      int hgt = int.Parse(n[3]);
      if (w <= 0 || hgt <= 0) continue;
      IntPtr next = CreateRectRgn(x, y, x + w, y + hgt);
      if (region == IntPtr.Zero) {
        region = next;
      } else {
        CombineRgn(region, region, next, 2);
        DeleteObject(next);
      }
    }
    if (region != IntPtr.Zero) SetWindowRgn(h, region, true);
  }
  public static void Clear(long hwnd) {
    SetWindowRgn((IntPtr)hwnd, IntPtr.Zero, true);
  }
}
"@
if ($Clear) { [BbPetShape]::Clear($Hwnd) }
elseif ($RectFile) { [BbPetShape]::Apply($Hwnd, $RectFile) }
