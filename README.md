# XcodeGroupSync

This project is able to synchronize a folder on disk with a group in Xcode project file (`pbxproj`). It works as follows:

1. under the specified root folder (`--src-root`)
2. for the specified xcodeproj project (`--path-to-xcodeproj`)
3. for the specified Target[1] (`--target-name`)
4. for the specified folder[2] (`--group-path`)
5. read all files from the specified folder (`--group-path`)
6. compare with all files in Xcode project group[3] and build phase of Target[1]
7. and add/remove only the difference between files on disk vs. references in `pbxproj`

```
[1] target from the specified xcodeproj
[2] folder from which to read file list
[3] group in Xcode project to which files will be added, the same as "root + generated-path" path
```

Once difference is detected, contents of the build phase are synchronized with the contents of the specified folder (`--group-path`).

The following arguments are accepted:

```bash
USAGE: xcode-group-sync --src-root <src-root> --group-path <group-path> --target-name <target-name> --path-to-xcodeproj <path-to-xcodeproj> --path-to-files <path-to-files> --filename-pattern <filename-pattern>

OPTIONS:
  --src-root <src-root>   $(SRC_ROOT) folder of the project
  --group-path <group-path>
                          Path to location of the group in project hierarchy, which would be used to locate the files' group within the `.pbxproj`
  --target-name <target-name>
                          Target name to which files would get assigned as compilable sources
  --path-to-xcodeproj <path-to-xcodeproj>
                          Custom .xcodeproj file location relative to `src-root` argument
  --path-to-files <path-to-files>
                          Custom path to files' folder relative to `group-path` argument
  --filename-pattern <filename-pattern>
                          Regex pattern for filenames to match in build phase (i.e. `*.generated.swift`)
  -h, --help              Show help information.
```
