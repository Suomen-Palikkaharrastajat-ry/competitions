/**
 * Client-side in-browser WebP image compression.
 *
 * Resizes large images (up to 1920px max dimension) and compresses them to
 * image/webp to save server disk space and network bandwidth.
 */

export function calculateDimensions(origWidth, origHeight, maxDimension = 1920) {
  if (
    typeof origWidth !== 'number' ||
    typeof origHeight !== 'number' ||
    !Number.isFinite(origWidth) ||
    !Number.isFinite(origHeight) ||
    origWidth <= 0 ||
    origHeight <= 0
  ) {
    return { width: origWidth, height: origHeight };
  }
  const maxDim = typeof maxDimension === 'number' && maxDimension > 0 ? maxDimension : 1920;
  if (origWidth <= maxDim && origHeight <= maxDim) {
    return { width: origWidth, height: origHeight };
  }
  if (origWidth >= origHeight) {
    return {
      width: maxDim,
      height: Math.max(1, Math.round((origHeight * maxDim) / origWidth)),
    };
  }
  return {
    width: Math.max(1, Math.round((origWidth * maxDim) / origHeight)),
    height: maxDim,
  };
}

export function toWebpFilename(filename) {
  if (typeof filename !== 'string' || !filename) {
    return 'image.webp';
  }
  const dotIndex = filename.lastIndexOf('.');
  const baseName = dotIndex > 0 ? filename.slice(0, dotIndex) : filename;
  return `${baseName}.webp`;
}

function isImageFile(file) {
  if (!file) return false;
  if (typeof file.type === 'string' && file.type.startsWith('image/')) {
    return true;
  }
  if (typeof file.name === 'string' && /\.(jpe?g|png|webp|gif|bmp)$/i.test(file.name)) {
    return true;
  }
  return false;
}

/**
 * Loads an image from a Blob/File and returns an object with width, height, and
 * a render function that draws onto a 2D canvas context.
 *
 * Uses createImageBitmap with { imageOrientation: 'from-image' } when available
 * to respect EXIF orientation metadata automatically.
 */
async function loadImageSource(file) {
  if (typeof createImageBitmap === 'function') {
    try {
      const bitmap = await createImageBitmap(file, { imageOrientation: 'from-image' });
      return {
        width: bitmap.width,
        height: bitmap.height,
        draw(ctx, w, h) {
          ctx.drawImage(bitmap, 0, 0, w, h);
        },
        cleanup() {
          bitmap.close();
        },
      };
    } catch (_) {
      // Fall through to HTMLImageElement if createImageBitmap fails on specific format
    }
  }

  // Fallback to Image element with object URL
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const img = new Image();
    const cleanupListeners = () => {
      img.onload = null;
      img.onerror = null;
      try {
        img.src = '';
      } catch (_) {}
    };
    img.onload = () => {
      const w = img.naturalWidth || img.width;
      const h = img.naturalHeight || img.height;
      resolve({
        width: w,
        height: h,
        draw(ctx, targetW, targetH) {
          ctx.drawImage(img, 0, 0, targetW, targetH);
        },
        cleanup() {
          cleanupListeners();
          URL.revokeObjectURL(url);
        },
      });
    };
    img.onerror = () => {
      cleanupListeners();
      URL.revokeObjectURL(url);
      reject(new Error(`Failed to load image: ${file.name}`));
    };
    img.src = url;
  });
}

/**
 * Compresses a single File or Blob to WebP.
 * If canvas WebP export is unsupported or times out, gracefully returns the original file.
 */
export async function compressImageFile(file, options = {}) {
  const maxDimension = options.maxDimension || 1920;
  const quality = typeof options.quality === 'number' ? options.quality : 0.82;

  // If running outside DOM or file is not an image, return original
  if (typeof document === 'undefined' || !isImageFile(file)) {
    return file;
  }

  let imageSource;
  try {
    imageSource = await loadImageSource(file);
  } catch (err) {
    // If decoding fails, re-throw so the caller can handle or fallback
    throw err;
  }

  try {
    const { width: targetWidth, height: targetHeight } = calculateDimensions(
      imageSource.width,
      imageSource.height,
      maxDimension
    );

    if (
      !targetWidth ||
      !targetHeight ||
      targetWidth <= 0 ||
      targetHeight <= 0 ||
      !Number.isFinite(targetWidth) ||
      !Number.isFinite(targetHeight)
    ) {
      return file;
    }

    const canvas = document.createElement('canvas');
    canvas.width = targetWidth;
    canvas.height = targetHeight;
    const ctx = canvas.getContext('2d');
    if (!ctx) {
      return file;
    }

    imageSource.draw(ctx, targetWidth, targetHeight);

    // Timeout guard: if browser fails to trigger toBlob callback within 5s, resolve null
    const blob = await new Promise((resolve) => {
      let settled = false;
      const timer = setTimeout(() => {
        if (!settled) {
          settled = true;
          resolve(null);
        }
      }, 5000);
      try {
        canvas.toBlob(
          (b) => {
            if (!settled) {
              settled = true;
              clearTimeout(timer);
              resolve(b);
            }
          },
          'image/webp',
          quality
        );
      } catch (_) {
        if (!settled) {
          settled = true;
          clearTimeout(timer);
          resolve(null);
        }
      }
    });

    // Clean up canvas memory
    canvas.width = 0;
    canvas.height = 0;

    // Check if browser supported image/webp in toBlob
    if (!blob || blob.type !== 'image/webp') {
      return file;
    }

    const webpName = toWebpFilename(file.name);
    return new File([blob], webpName, {
      type: 'image/webp',
      lastModified: Date.now(),
    });
  } finally {
    if (imageSource && typeof imageSource.cleanup === 'function') {
      imageSource.cleanup();
    }
  }
}

/**
 * Compresses an array or FileList of images sequentially.
 * If an individual image fails to process, it falls back to the original file
 * rather than discarding the entire batch.
 */
export async function compressImages(files, options = {}) {
  if (!files || files.length === 0) {
    return [];
  }

  const fileArray = Array.from(files);
  const remainingSlots =
    typeof options.remainingSlots === 'number' && options.remainingSlots > 0
      ? options.remainingSlots
      : fileArray.length;

  const toProcess = fileArray.slice(0, remainingSlots);
  const results = [];

  for (const file of toProcess) {
    try {
      const compressed = await compressImageFile(file, options);
      results.push(compressed);
    } catch (_) {
      // Graceful fallback to original file on individual decoding failure
      results.push(file);
    }
  }

  return results;
}
