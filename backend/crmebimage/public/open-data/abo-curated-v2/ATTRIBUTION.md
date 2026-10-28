# Amazon Berkeley Objects Attribution

The product metadata and source images in this directory come from the
[Amazon Berkeley Objects (ABO) dataset](https://amazon-berkeley-objects.s3.amazonaws.com/index.html).

Credit for the data and images:

> Amazon.com

Credit for building the dataset, archives, and benchmark sets:

> Matthieu Guillaumin (Amazon.com), Thomas Dideriksen (Amazon.com),
> Kenan Deng (Amazon.com), Himanshu Arora (Amazon.com),
> Jasmine Collins (UC Berkeley), and Jitendra Malik (UC Berkeley)

ABO is licensed under the
[Creative Commons Attribution 4.0 International License](https://creativecommons.org/licenses/by/4.0/).
The complete license text is included in `LICENSE-CC-BY-4.0.txt`.

## Local modifications

- Selected 120 listings for balanced coverage of the local demo categories.
- Rewrote display titles and short descriptions in Chinese without adding
  unsupported product claims.
- Converted each approved main image to an 800x800 RGB JPEG by applying EXIF
  orientation, proportional Lanczos scaling, and white-background padding.
- Added deterministic local demo prices, inventory, sales, sorting, and SKU
  identifiers. These values do not come from ABO.

The source listing and image identifiers, source path, dimensions, and SHA-256
checksums are recorded in `backend/sql/data/abo-curated-v2.json`.

Amazon.com and the dataset builders do not endorse this project or the local
changes.
