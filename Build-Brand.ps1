$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$visual=New-Object Windows.Media.DrawingVisual
$drawing=$visual.RenderOpen()
$drawing.DrawRoundedRectangle([Windows.Media.BrushConverter]::new().ConvertFromString('#B8F3CC'),$null,[Windows.Rect]::new(0,0,256,256),68,68)
$pen=New-Object Windows.Media.Pen([Windows.Media.BrushConverter]::new().ConvertFromString('#16271F'),12)
$pen.StartLineCap='Round'; $pen.EndLineCap='Round'; $pen.LineJoin='Round'
$geometry=[Windows.Media.Geometry]::Parse('M17,34 V17 H48 V42 H34 M34,49 H45 M39,42 V49 M17,45 V50 M17,33 A17,17 0 0 1 34,50 M17,41 A9,9 0 0 1 26,50')
$geometry=$geometry.Clone()
$geometry.Transform=New-Object Windows.Media.ScaleTransform(4,4)
$drawing.DrawGeometry($null,$pen,$geometry); $drawing.Close()
$image=New-Object Windows.Media.Imaging.RenderTargetBitmap(256,256,96,96,[Windows.Media.PixelFormats]::Pbgra32)
$image.Render($visual)
$encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder
$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($image))
$memory=New-Object IO.MemoryStream
$encoder.Save($memory); $bytes=$memory.ToArray(); $memory.Dispose()
[IO.File]::WriteAllBytes((Join-Path $PSScriptRoot 'assets\mark.png'),$bytes)
$file=[IO.File]::Create((Join-Path $PSScriptRoot 'assets\freescreen.ico'))
$writer=New-Object IO.BinaryWriter($file)
try {
    $writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]1)
    $writer.Write([byte]0); $writer.Write([byte]0); $writer.Write([byte]0); $writer.Write([byte]0)
    $writer.Write([uint16]1); $writer.Write([uint16]32); $writer.Write([uint32]$bytes.Length); $writer.Write([uint32]22); $writer.Write($bytes)
} finally { $writer.Dispose() }
