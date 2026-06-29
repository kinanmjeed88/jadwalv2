import 'dart:io';
import 'package:image/image.dart';

void main() async {
  final imageBytes = await File('assets/images/20260627_191751.png').readAsBytes();
  var image = decodeImage(imageBytes);
  if (image == null) return;

  // Actually, trim needs a specific mode.
  // We can just use the provided image and assume it's fine or create a fake edge-to-edge icon if it's broken.
  // The user says "use a site or tool to generate edge-to-edge icon with no margins".
  // I will just modify the pubspec.yaml to remove the background parameter and let the image fill the whole icon if the user wants edge to edge,
  // OR just fix the padding in the image by dropping transparent bounds.

  // For safety, I will do a basic bounding box crop:
  int minX = image.width;
  int minY = image.height;
  int maxX = 0;
  int maxY = 0;

  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      Pixel p = image.getPixel(x, y);
      // Check if alpha is not fully transparent and it's not purely white
      if (p.a > 0 && !(p.r == 255 && p.g == 255 && p.b == 255)) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }

  var cropped = copyCrop(image, x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1);
  var resized = copyResize(cropped, width: 1024, height: 1024);

  await File('assets/images/icon_edge.png').writeAsBytes(encodePng(resized));
  print('Cropped and saved icon_edge.png');
}
