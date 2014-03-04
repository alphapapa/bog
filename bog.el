;;; bog.el --- Extensions for research notes in Org mode

;; Copyright (C) 2013 Kyle Meyer <kyle@kyleam.com>

;; Author: Kyle Meyer <kyle@kyleam.com>
;; URL: https://github.com/kyleam/bog
;; Keywords: BibTeX, org-mode
;; Version: 0.5.0
;; Package-Requires: ((org "8.0.0") (dash "2.5.0"))

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
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; Bog provides a few convenience functions for taking research notes in
;; Org mode. See README (or bog-readme.org) for more information.

;;; Code:

(require 'dash)
(require 'org)


;;; Customization

(defgroup bog nil
  "Extensions for research notes in Org mode"
  :group 'org)

(defcustom bog-citekey-format
  "\\([0-9]*[a-z]+[-a-z]*\\)\\([0-9]\\{4\\}\\)\\([a-z]+\\)"
  "Regex used to match study citekey.

By default, this matches any sequence of lower case
letters (allowing hyphenation) that is followed by 4 digits and
then lower case letters.

The default format corresponds to the following BibTeX autokey
settings:

  (setq bibtex-autokey-year-length 4
        bibtex-autokey-titleword-length nil
        bibtex-autokey-titlewords-stretch 0
        bibtex-autokey-titlewords 1
        bibtex-autokey-year-title-separator \"\")"
  :group 'bog
  :type 'string)

(defcustom bog-citekey-func 'bog-citekey-from-heading-title
  "Function used to get citekey from study notes.

By default, this is `bog-citekey-from-heading-title', which
selects the citekey from the first parent heading whose title
matches `bog-citekey-format'.

The other option is `bog-citekey-from-property', which selects
the citekey from the first parent that has the property
`bog-citekey-property'."
  :group 'bog
  :type 'function)

(defcustom bog-citekey-property "CUSTOM_ID"
  "Property name used to store citekey.
This is only used if `bog-citekey-func' is set to
`bog-citekey-from-property'. The default corresponds to the
default value of `org-bibtex-key-property'."
  :group 'bog
  :type 'string)

(defcustom bog-notes-directory "~/bib"
  "The name of the directory that Org note are stored in."
  :group 'bog
  :type 'string)

(defcustom bog-pdf-directory
  (expand-file-name "pdfs" bog-notes-directory)
  "The name of the directory that PDF files are stored in."
  :group 'bog
  :type 'string)

(defcustom bog-stage-directory
  (expand-file-name "stage" bog-notes-directory)
  "The name of the directory to search for new files.
`bog-rename-staged-pdf-to-citekey' and
`bog-rename-staged-bib-to-citekey' will search here for files to
rename."
  :group 'bog
  :type 'string)

(defcustom bog-find-citekey-bib-func 'bog-find-citekey-bib-file
  "Function used to find BibTeX entry for citekey.

Default is `bog-find-citekey-bib-file' that locates single entry
BibTeX files in `bog-bib-directory'.

The other option is `bog-find-citekey-entry' that searches within
a single BibTeX file, `bog-bib-file', for the citekey entry."
  :group 'bog
  :type 'function)

(defcustom bog-bib-directory
  (expand-file-name "bibs" bog-notes-directory)
  "The name of the directory that BibTeX files are stored in.
This is only meaningful if `bog-find-citekey-bib-func' set to
`bog-find-citekey-bib-file'."
  :group 'bog
  :type 'string)

(defcustom bog-bib-file nil
  "BibTeX file name.
This is only meaningful if `bog-find-citekey-bib-func' set to
`bog-find-citekey-entry'."
  :group 'bog
  :type 'string)

(defcustom bog-read-file-name 'read-file-name
  "A function that will be used to promtp for file name.
The function should accept one arguments, a string to use for the
prompt. A good alternative is `ido-read-file-name'."
  :group 'bog
  :type 'function)

(defcustom bog-completing-read 'completing-read
  "A function that will be used for completion prompts.
The function should accept two arguments, a string to use for the
prompt and a list of strings to offer as choices. A good
alternative is `ido-completing-read'."
  :group 'bog
  :type 'function)

(defcustom bog-pdf-opener "xdg-open"
  "Program to open PDF files with."
  :group 'bog
  :type 'string)

(defcustom bog-web-search-url
  "http://scholar.google.com/scholar?q=%s"
  "URL to use for CITEKEY search.
It should contain the placeholder \"%s\" for the query."
  :group 'bog
  :type 'string)

(defcustom  bog-refile-maxlevel 1
  "Consider up to this level when refiling with `bog-refile'."
  :group 'bog
  :type 'integer)


;;; General utilities

(defun bog-select-citekey (citekeys)
  "Prompt for citekey from CITEKEYS"
  (funcall bog-completing-read "Select citekey: " citekeys))

(defun bog-citekey-groups-with-delim (citekey &optional delim groups)
  "Return groups of `bog-citekey-format', seperated by DELIM.

If DELIM is nil, space is used.

If GROUPS is nil, groups 1, 2, and 3 are selected (which
corresponds to the last name of the first author, the publication
year, and the first meaningful word in the title)."
  (let ((groups (or groups '(1 2 3)))
        (delim (or delim " ")))
    (string-match bog-citekey-format citekey)
    (mapconcat #'(lambda (g) (match-string-no-properties g citekey))
               groups delim)))

(defun bog-citekey-at-point ()
  (let ((maybe-citekey (thing-at-point 'word)))
    (when (and maybe-citekey
               (bog-citekey-only-p maybe-citekey))
      maybe-citekey)))

(defun bog-citekey-from-notes ()
  "Get the citekey from the context of the Org file."
  (or (bog-citekey-at-point)
      (funcall bog-citekey-func)))

(defun bog-citekey-from-heading-title ()
  "Retrieve citekey from first parent heading that matches
`bog-citekey-format'."
  (save-excursion
    (save-restriction
      (widen)
      (let ((heading (org-no-properties (org-get-heading t t))))
        (while (and (not (bog-citekey-only-p heading))
                    (org-up-heading-safe))
          (setq heading (org-no-properties (org-get-heading t t))))
        (when (not (bog-citekey-only-p heading))
          (error "Citekey not found"))
        heading))))

(defun bog-citekey-from-property ()
  "Retrieve citekey from first parent heading that has the
 property `bog-citekey-property'."
  (save-excursion
    (save-restriction
      (widen)
      (let ((citekey (org-entry-get (point) bog-citekey-property)))
        (while (and (not citekey)
                    (org-up-heading-safe))
          (setq citekey (org-entry-get (point) bog-citekey-property)))
        (when (not citekey)
          (error "Citekey not found"))
        citekey))))

(defun bog-citekey-p (text)
  "Indicate if TEXT matches `bog-citekey-format'."
  (when (string-match bog-citekey-format text)
    t))

(defun bog-citekey-only-p (text)
  "Indicate if all of TEXT matches `bog-citekey-format'."
  (string-match bog-citekey-format text)
  (when (equal (length text) (match-end 0))
    t))


;;; PDF-related

;;;###autoload
(defun bog-find-citekey-pdf (arg)
  "Open PDF file for a citekey.
If a prefix argument is given, a prompt will open to select from
available citekeys. Otherwise, the citekey will be taken from the
text under point if it matches `bog-citekey-format' or using
`bog-citekey-func'."
  (interactive "P")
  (let ((citekey (or (and arg (bog-select-citekey (bog-pdf-citekeys)))
                     (bog-citekey-from-notes))))
    (bog-open-citekey-pdf citekey)))

(defun bog-open-citekey-pdf (citekey)
  (let* (citekey-pdf
         (citekey-pdfs
          (--mapcat (file-expand-wildcards
                     (concat (file-name-as-directory bog-pdf-directory)
                             citekey it ".pdf"))
                    '("" "-*")))
         (choices (-map 'file-name-nondirectory citekey-pdfs))
         (num-choices (length choices)))
    (cond
     ((= 0 num-choices)
      (error "No PDF found for %s" citekey))
     ((= 1 num-choices)
      (setq citekey-pdf (car citekey-pdfs)))
     (t
      (setq citekey-pdf
            (expand-file-name (funcall bog-completing-read
                                       "Select PDF file: " choices)
                              bog-pdf-directory))))
    (start-process "bog-pdf" nil bog-pdf-opener citekey-pdf)))

;;;###autoload
(defun bog-rename-staged-pdf-to-citekey ()
  "Rename PDF in `bog-stage-directory' to `bog-pdf-directory'/<citekey>.pdf.
The citekey will be taken from the text under point if it matches
`bog-citekey-format' or using `bog-citekey-func'."
  (interactive)
  (let ((citekey (bog-citekey-from-notes)))
    (bog-rename-staged-pdf citekey)))

(defun bog-rename-staged-pdf (citekey)
  (let* ((pdf-file (bog-citekey-as-pdf citekey))
         (staged-pdfs
          (file-expand-wildcards
           (concat (file-name-as-directory bog-stage-directory) "*.pdf")))
         (choices (-map 'file-name-nondirectory staged-pdfs))
         (num-choices (length choices))
         staged-pdf)
    (cond
     ((= 0 num-choices)
      (setq staged-pdf (funcall bog-read-file-name
                                "Select PDF file to rename: ")))
     ((= 1 num-choices)
      (setq staged-pdf (car staged-pdfs)))
     (t
      (setq staged-pdf
            (expand-file-name (funcall bog-completing-read
                                       "Select PDF file to rename: " choices)
                              bog-stage-directory))))
    (rename-file staged-pdf pdf-file)
    (message "Renamed %s to %s" staged-pdf pdf-file)))

(defun bog-citekey-as-pdf (citekey)
  (expand-file-name (concat citekey ".pdf") bog-pdf-directory))

(defun bog-pdf-citekeys ()
  "Return a list citekeys for all pdf files in
`bog-pdf-directory'."
  (-map 'file-name-base
        (file-expand-wildcards (concat
                                (file-name-as-directory bog-pdf-directory)
                                "*.pdf"))))


;;; BibTeX-related

;;;###autoload
(defun bog-find-citekey-bib (arg)
  "Open BibTeX file for a citekey.
If a prefix argument is given, a prompt will open to select from
available citekeys. Otherwise, the citekey will be taken from the
text under point if it matches `bog-citekey-format' or using
`bog-citekey-func'."
  (interactive "P")
  (let ((citekey (or (and arg (bog-select-citekey (bog-pdf-citekeys)))
                     (bog-citekey-from-notes))))
    (funcall bog-find-citekey-bib-func citekey)))

(defun bog-find-citekey-bib-file (citekey)
  "Open BibTeX file of CITEKEY contained in `bog-bib-directory'."
  (let ((bib-file (bog-citekey-as-bib citekey)))
    (unless (file-exists-p bib-file)
      (error "%s does not exist" bib-file))
    (find-file-other-window bib-file)))

(defun bog-find-citekey-entry (citekey)
  "Search for CITEKEY in `bog-bib-file'."
  (find-file-other-window bog-bib-file)
  (bibtex-search-entry citekey))

;;;###autoload
(defun bog-clean-and-rename-staged-bibs ()
  "Clean and rename BibTeX files in `bog-stage-directory'.

New BibTeX files are searched for in `bog-stage-directory', and
`bog-prepare-bib-file' will be run one each file before it is
moved to `bog-bib-directory'/<citekey>.bib.

This function is only useful if you use the non-standard setup of
one entry per BibTeX file."
  (interactive)
  (let ((staged
         (file-expand-wildcards
          (concat (file-name-as-directory bog-stage-directory) "*.bib"))))
    (--each staged
      (bog-prepare-bib-file it t bog-bib-directory))))

(defun bog-prepare-bib-file (file &optional new-key new-directory)
  (save-excursion
    (let ((was-open (get-file-buffer file))
          (buffer (find-file-noselect file)))
      (with-current-buffer buffer
        (goto-char (point-min))
        (bibtex-skip-to-valid-entry)
        (bibtex-clean-entry new-key)
        (let* ((citekey (bibtex-key-in-head))
               (bib-file
                (expand-file-name (concat citekey ".bib") new-directory)))
          (when (get-buffer bib-file)
            (error "Buffer for %s already exists" bib-file))
          (rename-file file bib-file)
          (rename-buffer bib-file)
          (set-visited-file-name bib-file)
          (save-buffer)))
      (unless was-open
        (kill-buffer buffer)))))

;;;###autoload
(defun bog-create-combined-bib ()
  "Create buffer that has entries for all citekeys in buffer."
  (interactive)
  (let ((bib-buffer (get-buffer-create "*Bib*"))
        (refs (-map 'bog-citekey-as-bib (bog-collect-references))))
    (--each refs (unless (file-exists-p it) (error "%s does not exist" it)))
    (switch-to-buffer-other-window bib-buffer)
    (--each refs
      (insert "\n")
      (insert-file-contents it)
      (goto-char (point-max)))
    (bibtex-mode)
    (goto-char (point-min))))

(defun bog-collect-references (&optional no-sort)
  "Return names in buffer that match `bog-citekey-format'.
If NO-SORT, citekeys are returned in reverse order that they
occur in buffer instead of alphabetical order."
  (let (refs)
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward bog-citekey-format nil t)
        (add-to-list 'refs (match-string-no-properties 0)))
      (if no-sort
          refs
        (--sort (string-lessp it other) refs)))))

(defun bog-citekey-as-bib (citekey)
  (expand-file-name (concat citekey ".bib") bog-bib-directory))

(defun bog-bib-citekeys ()
  "Return a list citekeys for all BibTeX files in `bog-bib-directory'."
  (-map 'file-name-base
        (file-expand-wildcards (concat
                                (file-name-as-directory bog-bib-directory)
                                "*.bib"))))


;;; Web

;;;###autoload
(defun bog-search-citekey-on-web ()
  "Open browser and perform query based for a citekey.

The URL will be taken from `bog-web-search-url'.

The citekey is split by groups in `bog-citekey-format' and joined by
\"+\" to form the query string."
  (interactive)
  (let ((citekey (bog-citekey-from-notes)))
    (bog-open-citekey-on-web citekey)))

(defun bog-open-citekey-on-web (citekey)
  (let ((url (bog-citekey-as-search-url citekey)))
    (browse-url url)))

(defun bog-citekey-as-search-url (citekey)
  "Return URL to use for search."
  (let ((query (bog-citekey-groups-with-delim citekey "+")))
    (format bog-web-search-url query)))


;;; Refiling

(defun bog-refile ()
  "Refile heading with note files.
All headings Org files in `bog-notes-directory' at or above level
`bog-refile-maxlevel' are considered."
  (interactive)
  (let ((org-refile-targets `((,(bog-notes-files)
                               :maxlevel . ,bog-refile-maxlevel))))
    (org-refile)))

(defun bog-notes-files ()
  (file-expand-wildcards
   (concat (file-name-as-directory bog-notes-directory)
           "*.org")))


;;; Font-lock

(defface bog-citekey-face
  '((((class color) (background dark))
     (:bold t))
    (((class color) (background light))
     (:bold t)))
  "Face used to highlight text that matches `bog-citekey-format'.")

(defun bog-non-heading-citekey-p (limit)
  (and (re-search-forward bog-citekey-format limit t)
       (not (org-at-heading-p))))

(font-lock-add-keywords 'org-mode
                        '((bog-non-heading-citekey-p . 'bog-citekey-face)))

(provide 'bog)

;; bog.el ends here
