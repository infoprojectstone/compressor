import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

@main enum ImageEngineSelfTest {
    static func main() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        for index in 0..<4 {
            let input = folder.appendingPathComponent("image-\(index).png")
            try makePNG(input, seed: index)
            let original = size(input)
            guard original > 2_000_000 else { fatalError("La imagen de prueba no supera 2 MB") }
            guard let output = try SafeImageCompressor.compress(input, targetMB: 1.0) else { fatalError("No se generó salida") }
            let final = Int64(output.count)
            guard final < original, final <= 1_000_000 else { fatalError("Resultado inválido: \(original) -> \(final)") }
        }
        print("OK: lote de 4 imágenes comprimido sin aumentos de tamaño")
    }
    private static func size(_ url: URL) -> Int64 { (try? url.resourceValues(forKeys:[.fileSizeKey]).fileSize).map(Int64.init) ?? 0 }
    private static func makePNG(_ url: URL, seed: Int) throws {
        let width=1400, height=1100; var pixels=[UInt8](repeating:255,count:width*height*4); var value=UInt64(seed+1)
        for i in stride(from:0,to:pixels.count,by:4) { value=value &* 6364136223846793005 &+ 1442695040888963407; pixels[i]=UInt8(truncatingIfNeeded:value>>24); pixels[i+1]=UInt8(truncatingIfNeeded:value>>32); pixels[i+2]=UInt8(truncatingIfNeeded:value>>40) }
        guard let provider=CGDataProvider(data:Data(pixels) as CFData), let image=CGImage(width:width,height:height,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue),provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent), let destination=CGImageDestinationCreateWithURL(url as CFURL,UTType.png.identifier as CFString,1,nil) else { fatalError("No se pudo crear la imagen") }
        CGImageDestinationAddImage(destination,image,nil); guard CGImageDestinationFinalize(destination) else { fatalError("No se pudo escribir la imagen") }
    }
}
