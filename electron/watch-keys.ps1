Add-Type -TypeDefinition @"
using System.Runtime.InteropServices;
public static class BbPetKeys {
  [DllImport("user32.dll")]
  public static extern short GetAsyncKeyState(int vKey);
  public static bool AnyTyping() {
    int[] extra = { 8, 9, 13, 32, 46, 186, 187, 188, 189, 190, 191, 192, 219, 220, 221, 222 };
    for (int k = 48; k <= 57; k++) if ((GetAsyncKeyState(k) & 0x8000) != 0) return true;
    for (int k = 65; k <= 90; k++) if ((GetAsyncKeyState(k) & 0x8000) != 0) return true;
    foreach (int k in extra) if ((GetAsyncKeyState(k) & 0x8000) != 0) return true;
    return false;
  }
}
"@
$prev = $false
while ($true) {
  $now = [BbPetKeys]::AnyTyping()
  if ($now -ne $prev) {
    if ($now) { Write-Output '1' } else { Write-Output '0' }
    [Console]::Out.Flush()
    $prev = $now
  }
  Start-Sleep -Milliseconds 60
}
