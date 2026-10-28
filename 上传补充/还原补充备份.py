"""Verify, join and decrypt the supplementary backup without printing its password."""

import argparse
import getpass
import hashlib
import json
from pathlib import Path
import shutil


def checksum(path):
    value = hashlib.sha256()
    with open(path, "rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--password-file", type=Path)
    parser.add_argument("--output", type=Path, default=Path("补充备份还原"))
    args = parser.parse_args()
    try:
        import pyzipper
    except ImportError:
        raise SystemExit("请先运行：python3 -m pip install pyzipper")

    base = Path(__file__).resolve().parent
    manifest = json.loads((base / "备份校验.json").read_text(encoding="utf-8"))
    for part in manifest["parts"]:
        source = base / part["name"]
        if source.stat().st_size != part["bytes"] or checksum(source) != part["sha256"]:
            raise SystemExit(f"分卷校验失败：{part['name']}")
    password = (
        args.password_file.read_text(encoding="utf-8").strip()
        if args.password_file else getpass.getpass("请输入单独保存的备份解密密码：")
    ).encode()
    args.output.mkdir(parents=True, exist_ok=True)
    zip_path = args.output / "项目补充备份.zip"
    tar_path = args.output / "原始补充文件.tar.gz"
    if zip_path.exists() or tar_path.exists():
        raise SystemExit("输出目录中已有备份文件，请选择新的输出目录。")
    with open(zip_path, "xb") as output:
        for part in manifest["parts"]:
            with open(base / part["name"], "rb") as source:
                shutil.copyfileobj(source, output)
    if checksum(zip_path) != manifest["zip_sha256"]:
        raise SystemExit("合并后的 ZIP 校验失败。")
    try:
        with pyzipper.AESZipFile(zip_path) as archive:
            archive.setpassword(password)
            with archive.open("原始补充文件.tar.gz") as source, open(tar_path, "xb") as output:
                shutil.copyfileobj(source, output)
        if checksum(tar_path) != manifest["tar_sha256"]:
            raise SystemExit("解密后的 TAR 校验失败。")
    except Exception:
        tar_path.unlink(missing_ok=True)
        raise
    print(f"分卷合并、AES 解密及完整性校验通过：{tar_path.resolve()}")
    print("使用 7-Zip 或 tar 解压该文件，即可恢复原始目录中的签名资料、SQL 和临时文件。")


if __name__ == "__main__":
    main()
