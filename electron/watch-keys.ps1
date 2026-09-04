Add-Type -TypeDefinition @"
using System.Runtime.InteropServices;
public static class BbPetKeys {
  [DllImport("user32.dll")]
  public static extern short GetAsyncKeyState(int vKey);
  public static bool Down(int vKey) {
    return (GetAsyncKeyState(vKey) & 0x8000) != 0;
  }
  public static bool AnyTyping() {
    int[] extra = { 8, 9, 13, 32, 46, 186, 187, 188, 189, 190, 191, 192, 219, 220, 221, 222 };
    for (int k = 48; k <= 57; k++) if (Down(k)) return true;
    for (int k = 65; k <= 90; k++) if (Down(k)) return true;
    foreach (int k in extra) if (Down(k)) return true;
    return false;
  }
}
"@
$prev = $false
$prevL = $false
while ($true) {
  $now = [BbPetKeys]::AnyTyping()
  if ($now -ne $prev) {
    if ($now) { Write-Output 'T1' } else { Write-Output 'T0' }
    [Console]::Out.Flush()
    $prev = $now
  }
  $nowL = [BbPetKeys]::Down(1)
  if ($nowL -ne $prevL) {
    if ($nowL) { Write-Output 'L1' } else { Write-Output 'L0' }
    [Console]::Out.Flush()
    $prevL = $nowL
  }
  Start-Sleep -Milliseconds 20
}
