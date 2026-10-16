import assert from 'node:assert/strict';
import test from 'node:test';

import {
  calculateDimensions,
  compressImages,
  toWebpFilename,
} from '../src/imageCompression.mjs';

test('calculateDimensions: scales down landscape image exceeding maxDimension preserving aspect ratio', () => {
  // Given a 4K landscape photo (3840x2160)
  const origWidth = 3840;
  const origHeight = 2160;

  // When calculating target dimensions for Full HD (1920px max)
  const result = calculateDimensions(origWidth, origHeight, 1920);

  // Then width is clamped to 1920 and height is scaled to 1080
  assert.deepEqual(result, { width: 1920, height: 1080 });
});

test('calculateDimensions: scales down portrait image exceeding maxDimension preserving aspect ratio', () => {
  // Given a high-res smartphone portrait photo (3024x4032)
  const origWidth = 3024;
  const origHeight = 4032;

  // When calculating target dimensions for Full HD (1920px max)
  const result = calculateDimensions(origWidth, origHeight, 1920);

  // Then height is clamped to 1920 and width is scaled proportionally
  assert.deepEqual(result, { width: 1440, height: 1920 });
});

test('calculateDimensions: does not upscale image smaller than maxDimension', () => {
  // Given a moderate resolution image (1280x720)
  const origWidth = 1280;
  const origHeight = 720;

  // When calculating target dimensions with 1920px max
  const result = calculateDimensions(origWidth, origHeight, 1920);

  // Then original dimensions are preserved without upscaling
  assert.deepEqual(result, { width: 1280, height: 720 });
});

test('calculateDimensions: scales down square image exceeding maxDimension', () => {
  // Given a square image (3000x3000)
  const origWidth = 3000;
  const origHeight = 3000;

  // When calculating target dimensions
  const result = calculateDimensions(origWidth, origHeight, 1920);

  // Then width and height are both 1920
  assert.deepEqual(result, { width: 1920, height: 1920 });
});

test('calculateDimensions: gracefully handles zero, negative, and non-finite dimensions', () => {
  // Given invalid or degenerate dimension values
  // When calculating target dimensions
  // Then dimensions are returned unchanged without throwing or NaN
  assert.deepEqual(calculateDimensions(0, 0, 1920), { width: 0, height: 0 });
  assert.deepEqual(calculateDimensions(-100, 200, 1920), { width: -100, height: 200 });
  assert.deepEqual(calculateDimensions(NaN, 500, 1920), { width: NaN, height: 500 });
  assert.deepEqual(calculateDimensions(100, Infinity, 1920), { width: 100, height: Infinity });
});

test('toWebpFilename: converts common image extensions to .webp', () => {
  // Given filenames with .jpg, .jpeg, .png, uppercase, and multiple dots
  // When converting to WebP filenames
  // Then the extension is replaced with .webp
  assert.equal(toWebpFilename('my_moc.jpg'), 'my_moc.webp');
  assert.equal(toWebpFilename('my_moc.jpeg'), 'my_moc.webp');
  assert.equal(toWebpFilename('MY_PHOTO.PNG'), 'MY_PHOTO.webp');
  assert.equal(toWebpFilename('moc.detail.view.jpeg'), 'moc.detail.view.webp');
  assert.equal(toWebpFilename('already_webp.webp'), 'already_webp.webp');
  assert.equal(toWebpFilename('no_ext'), 'no_ext.webp');
  assert.equal(toWebpFilename(''), 'image.webp');
  assert.equal(toWebpFilename(null), 'image.webp');
  assert.equal(toWebpFilename(123), 'image.webp');
});

test('compressImages: respects remainingSlots and handles empty inputs', async () => {
  // Given an empty input
  const emptyResult = await compressImages([]);
  assert.deepEqual(emptyResult, []);

  // Given 3 mock files and remainingSlots = 2
  const mockFiles = [
    { name: '1.jpg', type: 'image/jpeg' },
    { name: '2.png', type: 'image/png' },
    { name: '3.webp', type: 'image/webp' },
  ];

  // When compressing with remainingSlots = 2
  const results = await compressImages(mockFiles, { remainingSlots: 2 });

  // Then only 2 items are processed
  assert.equal(results.length, 2);
  assert.equal(results[0].name, '1.jpg');
  assert.equal(results[1].name, '2.png');
});

test('compressImages: recognizes files with missing MIME type by extension', async () => {
  // Given files with empty type string but image extensions (common OS behavior)
  const mockFiles = [
    { name: 'photo.jpg', type: '' },
    { name: 'document.pdf', type: '' },
  ];

  // When compressing
  const results = await compressImages(mockFiles);

  // Then files are returned without throwing
  assert.equal(results.length, 2);
  assert.equal(results[0].name, 'photo.jpg');
  assert.equal(results[1].name, 'document.pdf');
});
