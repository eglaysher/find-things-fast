*Find Things Fast*

A mode for emacs that helps you work with projects, hopefully with little to no additional configuration on your part.

FTF should automatically detect your projects in most cases, as it can:

- Detect emacs22 style `.emacs-project` files or emacs23 style `.dir-locals.el` files.
- Detect being in a git tree (and uses the repository root as project root)
- Detect roots declared by the 3rd party `project-root.el` package.

FTF will leverage git utilities for speed when used in a git repository, falling back to find commands when git is unavailable.

**Main Features**

- `ftf-find-file` looks in the current project, creates a list of all files that match a user editable list of file extensions, and lets you navigate without worrying about directories. Uses `ido-mode` if you have that turned on, `completing-read` otherwise. On a git controlled [chromium][chromium] checkout, this takes less than one second.

- `ftf-grepsource` greps all files in your project that match the list of file extensions.

- `ftf-compile` and `ftf-gdb` run `compile` and `gdb` from the root of your project. 

Sample configuration (from my .emacs):

    (require 'find-things-fast)
    (global-set-key '[f1] 'ftf-find-file)
    (global-set-key '[f2] 'ftf-grepsource)
    (global-set-key '[f4] 'ftf-gdb)
    (global-set-key '[f5] 'ftf-compile)
