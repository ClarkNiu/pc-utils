# Force Delete Script 强制删除脚本

[中文](#中文) | [English](#english)

---

## 中文

### 概述
这是一个 Windows 批处理脚本，用于强制删除被系统锁定或权限不足无法删除的文件和文件夹。脚本通过获取所有权、授予完全控制权限、强制删除三个步骤解决问题。

### 功能
- 自动以管理员权限运行
- **检测并关闭锁定进程**：自动识别并尝试关闭锁定目标的进程（支持 handle.exe 辅助检测）
- 递归获取文件和文件夹的所有权
- 为所有用户授予完全控制权限
- 强制删除目标文件或文件夹（支持重试机制）
- 支持路径包含空格和特殊字符
- 提供彩色编码的详细执行日志
- **智能验证机制**：验证权限设置和所有权转移是否成功
- **容错处理**：每个操作都有重试机制和错误处理
- **进程管理**：优雅关闭进程，如失败则强制终止

### 文件说明
- `force-delete.bat` - 批处理包装脚本，提供简单命令行界面
- `force-delete.ps1` - PowerShell 核心脚本，执行实际删除操作

### 使用方法
```cmd
force-delete.bat "文件或文件夹路径"
```

示例：
```cmd
# 删除被锁定的文件夹
force-delete.bat "C:\Program Files (x86)\ZeroTier"

# 删除被锁定的文件
force-delete.bat "C:\temp\locked_file.txt"
```

### 工作原理
0. **检测锁定进程** - 检查并尝试关闭锁定目标文件/文件夹的进程（支持 handle.exe 增强检测）
1. **获取所有权** - 使用 `takeown` 命令获取目标路径的所有权（支持递归）
2. **授予权限** - 使用 `icacls` 为 "Everyone" 组授予完全控制权限（支持递归）
3. **强制删除** - 使用 PowerShell `Remove-Item -Recurse -Force` 强制删除目标（最多重试 3 次）

### 系统要求
- Windows 7/8/10/11
- PowerShell 5.1 或更高版本
- 管理员权限（脚本会自动请求）

### 免责声明

1. 本脚本仅用于个人设备的合法文件管理，严禁用于删除他人数据、系统文件或任何违法用途
2. 使用前请备份重要数据，作者对使用脚本导致的任何数据丢失、系统损坏不承担责任
3. 仅授权个人非商业使用，禁止二次传播、修改或用于商业目的
4. 若你不同意上述条款，请勿下载或使用本脚本

### 注意事项
1. **管理员权限**：脚本需要管理员权限才能修改系统文件和受保护的文件
2. **防病毒软件**：某些安全软件可能阻止权限修改操作
3. **系统文件**：删除系统关键文件可能导致系统不稳定
4. **数据安全**：此操作不可逆，请确认目标路径正确
5. **路径引号**：路径包含空格时必须使用引号包裹
6. **锁定进程**：脚本会自动检测并尝试关闭锁定文件的进程，关闭前会提示确认
7. **Handle.exe 支持**：如有 Sysinternals Handle 工具（需添加到 PATH），可增强锁定进程检测能力

### 故障排除

#### 错误：无效参数/选项
**原因**：路径包含空格但没有用引号包裹
**解决**：确保路径使用双引号：
```cmd
force-delete.bat "C:\Program Files (x86)\App"
```

#### 错误：权限不足
**原因**：管理员权限未正确获取
**解决**：
1. 手动以管理员身份运行命令提示符
2. 执行脚本：`force-delete.bat "路径"`

#### 错误：删除失败（访问被拒绝）
**原因**：文件被其他进程锁定
**解决**：
1. 关闭使用该文件的程序
2. 使用任务管理器结束相关进程
3. 重启电脑后重试

#### 权限授予失败
**原因**：某些系统需要直接使用SID
**解决**：修改 `force-delete.ps1` 第97和100行：
```powershell
# 将 "Everyone" 改为 "*S-1-1-0"
$icaclsArgs = @("`"$($item.FullName)`"", "/grant", "*S-1-1-0:(OI)(CI)F", "/T", "/C", "/Q")
```

### 手动替代命令
如果脚本不可用，可手动执行以下命令：

```cmd
# 获取所有权（文件夹）
takeown /f "路径" /r /d y

# 授予权限（文件夹）
icacls "路径" /grant Everyone:(OI)(CI)F /T /C /Q

# 删除文件夹
rmdir /s /q "路径"
```

---

## English

### Overview
This is a Windows batch script designed to force delete files and folders that are locked by the system or inaccessible due to insufficient permissions. The script resolves issues through three steps: taking ownership, granting full control permissions, and force deletion.

### Features
- Automatically runs with administrator privileges
- **Locking Process Detection**: Automatically identifies and attempts to close processes locking the target (supports handle.exe for enhanced detection)
- Recursively takes ownership of files and folders
- Grants full control permissions to all users
- Force deletes target files or folders (with retry mechanism)
- Supports paths with spaces and special characters
- Provides color-coded detailed execution logs
- **Smart Verification**: Verifies that permissions and ownership are actually set correctly
- **Fault Tolerance**: Each operation includes retry mechanisms and error handling
- **Process Management**: Gracefully closes processes, with forced termination as fallback

### File Description
- `force-delete.bat` - Batch wrapper script, provides simple command-line interface
- `force-delete.ps1` - PowerShell core script, performs actual deletion operations

### Usage
```cmd
force-delete.bat "file_or_folder_path"
```

Examples:
```cmd
# Delete locked folder
force-delete.bat "C:\Program Files (x86)\ZeroTier"

# Delete locked file
force-delete.bat "C:\temp\locked_file.txt"
```

### How It Works
0. **Detect Locking Processes** - Checks for and attempts to close processes locking the target file/folder (handle.exe supported for enhanced detection)
1. **Take Ownership** - Uses `takeown` command to take ownership of the target path (recursive support)
2. **Grant Permissions** - Uses `icacls` to grant full control permissions to the "Everyone" group (recursive support)
3. **Force Delete** - Uses PowerShell `Remove-Item -Recurse -Force` to force delete the target (up to 3 retries)

### System Requirements
- Windows 7/8/10/11
- PowerShell 5.1 or higher
- Administrator privileges (script will automatically request)

### Disclaimer

1. This script is intended solely for legal file management on personal devices. It is strictly prohibited to use it for deleting others' data, system files, or any illegal purposes.
2. Please back up important data before use. The author is not responsible for any data loss or system damage caused by using this script.
3. Only authorized for personal non-commercial use. Secondary distribution, modification, or commercial use is prohibited.
4. If you do not agree to the above terms, do not download or use this script.

### Important Notes
1. **Administrator Privileges**: Script requires admin rights to modify system files and protected files
2. **Antivirus Software**: Some security software may block permission modification operations
3. **System Files**: Deleting critical system files may cause system instability
4. **Data Safety**: This operation is irreversible, ensure the target path is correct
5. **Path Quotes**: Paths containing spaces must be enclosed in quotes
6. **Locking Processes**: Script automatically detects and attempts to close locking processes, prompt for confirmation before closing
7. **Handle.exe Support**: Enhanced locking process detection available if Sysinternals Handle tool is in PATH

### Troubleshooting

#### Error: Invalid parameter/option
**Cause**: Path contains spaces but not enclosed in quotes
**Solution**: Ensure paths use double quotes:
```cmd
force-delete.bat "C:\Program Files (x86)\App"
```

#### Error: Insufficient permissions
**Cause**: Administrator privileges not properly obtained
**Solution**:
1. Manually run Command Prompt as Administrator
2. Execute script: `force-delete.bat "path"`

#### Error: Delete failed (Access denied)
**Cause**: File locked by another process
**Solution**:
1. Close programs using the file
2. Use Task Manager to end related processes
3. Try again after restarting computer

#### Permission grant failure
**Cause**: Some systems require direct use of SID
**Solution**: Modify lines 97 and 100 in `force-delete.ps1`:
```powershell
# Change "Everyone" to "*S-1-1-0"
$icaclsArgs = @("`"$($item.FullName)`"", "/grant", "*S-1-1-0:(OI)(CI)F", "/T", "/C", "/Q")
```

### Manual Alternative Commands
If the script is unavailable, manually execute the following commands:

```cmd
# Take ownership (folder)
takeown /f "path" /r /d y

# Grant permissions (folder)
icacls "path" /grant Everyone:(OI)(CI)F /T /C /Q

# Delete folder
rmdir /s /q "path"
```

### License
This script is provided as-is without warranty. Use at your own risk.

### Version History
- v1.0 - Initial release
- v1.1 - Fixed path quoting issues for paths with spaces
- v1.1 - Improved error handling and logging
- v1.2 - Added locking process detection and termination
- v1.2 - Enhanced ownership verification logic
- v1.2 - Added comprehensive retry and verification mechanisms

### Author
Auto-generated script for force deletion operations.

---

**Disclaimer**: Use this script responsibly. Deleting system files or important data may cause irreversible damage. Always verify the target path before execution.