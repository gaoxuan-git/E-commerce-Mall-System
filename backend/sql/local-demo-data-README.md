# Local Demo Data

`local-demo-data.sql` is the only demo database import entry point. It installs
a curated product catalog and realistic local activity without removing
unowned business products.

## Included data

- 120 curated products covering all 34 enabled leaf categories, 3-4 products per category
- One source-consistent SKU and one verified 800x800 local image per product
- 100 users, 130 addresses, 400 account records, and 6000 visit records
- 600 orders across unpaid, shipping, received, review, completed, and refunded states
- 210 product reviews, 12 coupons, and 300 coupon ownership records
- 12 seckill, 10 bargain, and 10 group-buy activities
- 30 articles and 60 days of trade/product statistics (7200 product-day records)
- Home theme product blocks synchronized to current curated product IDs

Product and article images are local files under
`backend/crmebimage/public/open-data/abo-curated-v2`. The development image
service must be available at `http://127.0.0.1:8080`.

## Source and license

Product metadata and images come from the
[Amazon Berkeley Objects (ABO)](https://amazon-berkeley-objects.s3.amazonaws.com/index.html)
dataset under CC BY 4.0.

The auditable source mapping is
`backend/sql/data/abo-curated-v2.json`. It records the ABO listing ID, main
image ID, source image path and dimensions, source/output SHA-256 values,
Chinese display fields, local demo values, and manual visual-review status.

Attribution and the complete license are stored beside the images in
`ATTRIBUTION.md` and `LICENSE-CC-BY-4.0.txt`. Local modifications are limited
to selection, Chinese display text, 800x800 white-background normalization,
and deterministic demo prices, inventory, sales, sorting, and SKU IDs.
Amazon.com and the dataset builders do not endorse these changes.

## Build and check

The running application does not require Python or an external image host.
Rebuilding the catalog requires Python 3 and Pillow. On the first online build
or full check, the tool downloads the official listing archive (about 87 MB),
image metadata (about 6.4 MB), license, and the 120 selected source images to
`/tmp/crmeb-abo-cache`:

- `abo-listings.tar`: official listing metadata archive
- `abo.sqlite3`: generated index containing the 120 selected listings
- `images.csv.gz`: official ABO image metadata
- `LICENSE-CC-BY-4.0.txt`: official license
- `curated-v2-source/`: downloaded selected source images

Install the pinned image dependency and rebuild:

```bash
python3 -m pip install -r backend/sql/tools/requirements-abo-demo.txt
python3 backend/sql/tools/build_abo_demo_catalog.py
```

Run the full source-to-SQL check when the cache is available:

```bash
python3 backend/sql/tools/build_abo_demo_catalog.py --check
```

For a repository-only integrity check without `/tmp` source files:

```bash
python3 backend/sql/tools/build_abo_demo_catalog.py --check --offline
```

The check rejects missing visual review, duplicate listing/image IDs,
unbalanced categories, source mapping drift, unexpected image files, checksum
changes, invalid dimensions, and SQL generated-block drift.

## Import

Create a backup, check artifacts, import, and clear Redis DB 10:

```bash
mysqldump -uroot -p123456 --single-transaction \
  --set-gtid-purged=OFF dexter_dianshang > /tmp/dexter_dianshang.sql
python3 backend/sql/tools/build_abo_demo_catalog.py --check
mysql -uroot -p123456 dexter_dianshang < backend/sql/local-demo-data.sql
redis-cli -n 10 FLUSHDB
```

The SQL is idempotent. Product cleanup is restricted to the ownership markers
`demo-seed-v1`, `abo-open-data-v1:*`, and `abo-curated-v2:*`. Demo users and
orders use `[DEMO-SEED-V1]`. Rows without those markers are retained.

To verify idempotency, import the same file a second time and compare table
counts before and after.

## Restore

Restore the backup and clear the derived cache:

```bash
mysql -uroot -p123456 dexter_dianshang < /tmp/dexter_dianshang.sql
redis-cli -n 10 FLUSHDB
```
