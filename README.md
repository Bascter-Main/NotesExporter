# NotesExporter

为 Apple 自带 **备忘录（Notes）** 增加导出能力的 TrollFools dylib 插件，主要面向 **iOS 17.0**。

本项目通过注入 `com.apple.mobilenotes`，在系统备忘录的列表界面增加单条与批量导出功能，并将备忘录内容整理为 JSON 文件后调用系统分享菜单导出。

## 功能

- **批量导出备忘录**
  - 在备忘录列表进入多选模式。
  - 同时选择 2 条及以上备忘录后，会出现 `导出所选 (N)` 按钮。
  - 点击后将当前选中的备忘录一次性导出。

- **单条备忘录导出**
  - 在备忘录列表中长按一条备忘录。
  - 在系统原有的上下文菜单中增加 `导出备忘录` 选项。
  - 不会在具体备忘录的查看 / 编辑页面显示导出按钮。

- **使用系统分享菜单**
  - 导出完成后自动打开 iOS 的 `UIActivityViewController`。
  - 可以保存到“文件”、AirDrop、发送到其他 App 等。

- **支持 arm64 / arm64e**
  - GitHub Actions 会构建并验证同时包含 `arm64` 和 `arm64e` 的通用 dylib。

## 导出格式

当前导出文件为 JSON。

批量导出的文件名类似：

```text
AppleNotes-Selected-20260901-120000.json
```

单条导出的文件名类似：

```text
AppleNote-20260901-120000.json
```

每条备忘录目前会尽量导出以下信息：

```json
{
  "title": "备忘录标题",
  "body": "备忘录纯文本正文",
  "created": "创建时间",
  "modified": "修改时间",
  "identifier": "Notes 内部标识",
  "objectID": "Core Data Object ID",
  "folder": "所在文件夹"
}
```

## 当前限制

当前版本主要用于导出 **文本内容和基础元数据**。

暂不保证完整保留：

- 富文本样式
- 字体 / 字号 / 颜色
- 图片和视频附件
- 扫描件
- 手写内容
- 表格
- 绘图
- 其他 Apple Notes 专有富媒体结构

因此，本项目更适合用于备忘录的 **文本备份、数据迁移或后续自行处理**，而不是完整还原 Apple Notes 原始排版。

## 兼容性

- 主要开发 / 实机测试环境：**iOS 17.0**
- 目标 App：Apple Notes / 系统备忘录
- Bundle ID：`com.apple.mobilenotes`
- 注入方式：TrollFools
- 架构：`arm64`、`arm64e`

Theos 工程的最低 Target 当前设置为 iOS 15.0，但项目主要针对 iOS 17.0 开发，其他系统版本没有保证兼容性。

## 安装

1. 获取编译后的：

```text
NotesExporter.dylib
```

2. 使用 TrollFools 将 dylib 注入系统备忘录：

```text
com.apple.mobilenotes
```

3. 完全关闭系统备忘录并重新打开。

4. 在备忘录列表中测试：
   - 长按单条备忘录 → `导出备忘录`
   - 多选至少 2 条备忘录 → `导出所选 (N)`

## GitHub Actions 自动构建

仓库内包含 GitHub Actions 工作流：

```text
.github/workflows/notes-exporter-ios17.yml
```

向 `main` 分支提交代码后会自动：

1. 在 macOS Runner 上安装 Theos 和 ldid。
2. 编译 `arm64 + arm64e` dylib。
3. 检查最终文件确实为动态库。
4. 检查 dylib 同时包含 `arm64` 和 `arm64e`。
5. 计算 SHA-256。
6. 将构建结果提交到：

```text
build-output/NotesExporter.dylib
build-output/NotesExporter.dylib.sha256
```

也可以在 GitHub Actions 页面手动运行 `Build NotesExporter iOS 17`。

## 本地编译

需要安装 Theos。

```bash
cd NotesExporterTrollFools
export THEOS="$HOME/theos"
make clean
make FINALPACKAGE=1
```

最终通用 dylib 通常位于：

```text
NotesExporterTrollFools/.theos/obj/NotesExporter.dylib
```

## 实现说明

插件运行于 Apple Notes 进程内部，主要通过：

- Notes 私有 `NotesShared.framework`
- `ICNoteContext`
- Core Data `NSManagedObjectID`
- Notes 列表的 `UICollectionView`
- iOS Context Menu

获取当前选中的备忘录，并从 Notes 的 Core Data 上下文读取对应记录后生成导出文件。

由于 Apple Notes 使用私有 Framework 和内部实现，本项目可能会受到不同 iOS 小版本内部结构变化的影响。

## 项目结构

```text
NotesExporter/
├── NotesExporterTrollFools/
│   ├── Tweak.m
│   ├── Makefile
│   └── control
├── .github/workflows/
│   └── notes-exporter-ios17.yml
├── build-output/
│   ├── NotesExporter.dylib
│   └── NotesExporter.dylib.sha256
└── README.md
```

## Disclaimer

本项目依赖 Apple 的私有 API / 私有 Framework，仅用于个人设备上的研究、备份和功能扩展。iOS 更新后不保证继续兼容。