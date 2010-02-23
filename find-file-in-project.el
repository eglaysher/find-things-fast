;;; find-things-fast.el --- Find things fast, leveraging the power of git

;; Copyright (C) 2010 Elliot Glaysher
;; Copyright (C) 2006, 2007, 2008 Phil Hagelberg and Doug Alcorn

;; Author: Phil Hagelberg and Doug Alcorn
;; URL: http://www.emacswiki.org/cgi-bin/wiki/FindFileInProject
;; Version: 1.0
;; Created: 2010-02-19
;; Keywords: project, convenience
;; EmacsWiki: FindThingsFast

;; This file is NOT part of GNU Emacs.

;;; License:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;; This file provides methods that quickly get you to your destination inside
;; your current project, leveraging the power of git if you are using it to
;; store your code.

;; A project is defined either as:
;;
;; - The git repository that the current buffer is in.
;; - The project root defined in project-root.el, a library not included with
;;   GNU Emacs.
;; - The current default-directory if none of the above is found.

;; When we're in a git repository, we use git-ls-files and git-grep to speed up
;; our searching. Otherwise, we fallback on find statements. As a special
;; optimization, we prune ".svn" directories whenever we find.

;; ftf provides two main user functions:
;;
;; - `ftf-find-file' which does a quick lookup on all 


;; This file provides a method for quickly finding any file in a given
;; project. Projects are defined as per the `project-local-variables'
;; library, by the presence of a `.emacs-project' file in a directory.

;; By default, it looks only for files whose names match
;; `ffip-regexp', but it's understood that that variable will be
;; overridden locally. This can be done either with a mode hook:

;; (add-hook 'emacs-lisp-mode-hook (lambda (setl ffip-regexp ".*\\.el")))

;; or by setting it in your .emacs-project file, in which case it will
;; get set locally by the project-local-variables library.

;; You can also be a bit more specific about what files you want to
;; find. For instance, in a Ruby on Rails project, you may be
;; interested in all .rb files that don't exist in the "vendor"
;; directory. In that case you could locally set `ffip-find-options'
;; to "" from within a hook or your .emacs-project file. The options
;; accepted in that variable are passed directly to the Unix `find'
;; command, so any valid arguments for that program are acceptable.

;; If `ido-mode' is enabled, the menu will use `ido-completing-read'
;; instead of `completing-read'.

;; Recommended binding:
;; (global-set-key (kbd "C-x C-M-f") 'find-file-in-project)

;;; Code:

(defvar ftf-filetypes
  '("*.h" "*.hpp" "*.cpp" "*.c" "*.cc" "*.cpp" "*.inl" "*.grd" "*.idl" "*.m"
    "*.mm" "*.py" "*.sh" "*.cfg" "*SConscript" "SConscript*" "*.scons"
    "*.vcproj" "*.vsprops" "*.make" "*.gyp" "*.gypi")
  "A list of filetype patterns that grepsource will use. Obviously biased for
chrome development.")

(defun ftf-get-find-command ()
  "Creates the raw, shared find command from `ftf-filetypes'."
  (concat "find . -path '*/.svn' -prune -o -name \""
          (mapconcat 'identity grepsource-filetypes "\" -or -name \"")
          "\""))

;; Adapted from git.el 's git-get-top-dir
(defun ftf-get-top-git-dir (dir)
  "Retrieve the top-level directory of a git tree. Returns nil on error or if
not a git repository.."
  ;; temp buffer for errors in toplevel git rev-parse
  (with-temp-buffer
    (if (eq 0 (call-process "git" nil t nil "rev-parse"))
        (let ((cdup (with-output-to-string
                      (with-current-buffer standard-output
                        (cd dir)
                        (call-process "git" nil t nil
                                      "rev-parse" "--show-cdup")))))
          (expand-file-name (concat (file-name-as-directory dir)
                                    (car (split-string cdup "\n")))))
      nil)))

(defun ftf-grepsource (cmd-args)
  "Greps the current project, leveraging local repository data
  for speed and falling back on a big \"find | xargs grep\"
  command if we aren't."
  (interactive (list (read-from-minibuffer "Grep project for string: ")))
  ;; When we're in a git repository, use git grep so we don't have to
  ;; find-files.
  (let ((quoted (replace-regexp-in-string "\"" "\\\\\"" cmd-args))
        (git-toplevel (ftf-get-top-git-dir default-directory))
        (default-directory (or (cdr project-details) default-directory))
        (grep-use-null-device nil))
    (cond (git-toplevel ;; We can accelerate our grep using the git data.
           (grep (concat "git --no-pager grep -n -e \"" quoted "\" -- "
                         (mapconcat 'identity grepsource-filetypes " "))))
          (t            ;; Fallback on find|xargs
             (grep (concat (ftf-get-find-command)
                           " | xargs grep -nH -e \"" quoted "\""))))))

(defun ftf-project-files-string ()
  "Returns a string with the raw output of ."
  (let ((git-toplevel (ftf-get-top-git-dir default-directory)))
    (cond (git-toplevel
           (shell-command-to-string
            (concat "git ls-files -- "
                    (mapconcat 'identity grepsource-filetypes " "))))
           (t
            (let ((default-directory (or (cdr project-details)
                                         default-directory)))
              (shell-command-to-string (ftf-get-find-command)))))))

(defun ftf-project-files-hash ()
  "Returns a hashtable filled with file names as the key and "
  (let ((default-directory (or (ftf-get-top-git-dir default-directory)
                               default-directory))
        (table (make-hash-table :test 'equal)))
    (mapcar (lambda (file)
              (let* ((file-name (file-name-nondirectory file))
                     (full-path (expand-file-name file))
                     (pathlist (cons full-path (gethash file-name table nil))))
                (puthash file-name pathlist table)))
            (split-string (ftf-project-files-string)))
    table))

(defun ftf-project-files-alist ()
  "Return an alist of all filenames in the project and their path.

Files with duplicate filenames are suffixed with the name of the
directory they are found in so that they are unique."
  (let ((table (ftf-project-files-hash))
        file-alist)
    (maphash (lambda (file-name full-path)
               (cond ((> (length full-path) 1)
                      (dolist (path full-path)
                        (let ((entry (cons file-name path)))
                          (ftf-uniqueify entry)
                          (add-to-list 'file-alist entry))))
                     (t
                      (add-to-list 'file-alist
                                   (cons file-name (car full-path))))))
             table)
    file-alist))

(defun ftf-uniqueify (file-cons)
  "Set the car of the argument to include the directory name plus the file name."
  (setcar file-cons
	  (concat (car file-cons) ": "
		  (cadr (reverse (split-string (cdr file-cons) "/"))))))

(defun find-file-in-project ()
  "Prompt with a completing list of all files in the project to find one.

The project's scope is defined as the first directory containing
an `.emacs-project' file. You can override this by locally
setting the `ftf-project-root' variable."
  (interactive)
  (let* ((project-files (ftf-project-files-alist))
	 (file (if (functionp 'ido-completing-read)
		   (ido-completing-read "Find file in project: "
					(mapcar 'car project-files))
		 (completing-read "Find file in project: "
				  (mapcar 'car project-files)))))
    (find-file (cdr (assoc file project-files)))))


(provide 'find-file-in-project)
;;; find-file-in-project.el ends here
