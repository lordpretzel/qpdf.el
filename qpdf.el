;;; qpdf.el --- An Emacs wrapper for qpdf -*- lexical-binding: t; -*-

;;; Commentary:

;; This requires that qpdf is installed and in your path.
;; Linux/Windows: https://github.com/qpdf/qpdf/releases/
;; MacOS: https://formulae.brew.sh/formula/qpdf

(require 'transient)
(require 'pdf-info)
(require 'pdf-view)

;;;###autoload
(transient-define-prefix qpdf ()
  "Transient dispatcher for the qpdf shell command.
See URL `https://qpdf.readthedocs.io/en/stable/cli.html#page-selection'
for details on the --pages argument and others."  
  :init-value 'qpdf--dispatch-init
  :incompatible '(("--replace-input" "--outfile="))
  ["Arguments"
   ("p" "pages" "--pages=" qpdf--read-pages)
   ("r" "replace input" "--replace-input")
   ("o" "outfile" "--outfile=" qpdf--read-outfile)]
  ["Actions"
   ("<return>" " qpdf-run" qpdf-run)]
  (interactive)
  (if (equal major-mode 'pdf-view-mode)
      (transient-setup 'qpdf)
    (error "Not in pdf-view-mode.")))

;;;###autoload
(defun qpdf--dispatch-init (obj)
  "Sets dynamic initial values for `qpdf'."
  (oset obj value `(,(concat "--outfile=" (qpdf--make-unique-filename (file-truename "qpdf-outfile.pdf"))))))


(defun qpdf-run (&optional args)
  "Runs shell command qpdf taking `ARGS' from `qpdf' transient."
  (interactive (list (transient-args transient-current-command)))
  (let ((infile (pdf-view-buffer-file-name))
	(pages (transient-arg-value "--pages=" args))
	(replace-input (transient-arg-value "--replace-input" args))
	(outfile (transient-arg-value "--outfile=" args)))
    (unless (or outfile replace-input)
      (error "Must specify either outfile or --replace-input."))
    (setq args (seq-difference args (list (concat "--outfile=" outfile))))
    ;; (print args)
    (let ((call (concat "qpdf" " " infile " " (mapconcat (lambda (x) (replace-regexp-in-string "^--pages=" "--pages" x)) args " ") " " outfile)))
      (message "call: %s" call)
      (call-process-shell-command call))
    (if replace-input
	(revert-buffer t t)
      (if (not (file-exists-p outfile))
	  (error "Cannot find outfile.")
	(let ((dark pdf-view-midnight-minor-mode))
	  (find-file outfile)
	  (when dark
	    (pdf-view-midnight-minor-mode)))))))


(defun qpdf--read-pages (arg _initial-input _history)
  "Reads a page range while providing some presets based on current page."
  (let* ((current-page (pdf-view-current-page))
	 (options `((?f "from current" from-current)
		    (?u "until current" until-current)
		    (?e "except current" except-current)
		    (?o "only current" only-current)
		    (?c "custom" custom)))
	 (choice-char             
	  (read-char-choice 
	   (mapconcat
	    (lambda (item) (format "%c: %s" (car item) (cadr item))) 
	    options "; ")
	   (mapcar #'car options)))
	 (choice (nth 2 (assoc choice-char options)))
	 (pages (cond ((equal choice 'from-current)
		       (concat " . " (number-to-string current-page) "-z" " --"))
		      ((equal choice 'until-current)
		       (concat " . 1-" (number-to-string current-page) " --"))
		      ((equal choice 'except-current)
		       (cond ((equal current-page (pdf-info-number-of-pages))
			      " . 1-r2 --")
			     ((equal current-page 1) " . 2-z --")
			     (t (concat " . 1-"
					(number-to-string (- current-page 1))
					"," 
					(number-to-string (+ current-page 1))
					"-z --"))))
		      ((equal choice 'only-current)
		       (concat " . " (number-to-string current-page) " --"))
		      ((equal choice 'custom)
		       (read-string "Pages: ")))))
    (message "")
    pages))


(defun qpdf--read-outfile (arg _initial-input _history)
  "Reads an outfile."
  (file-truename (read-file-name "Outfile: ")))


(defun qpdf--make-unique-filename (filename)
  "Increments `filename' until it is unique."
  (let ((num 1)
	new-filename)
    (if (file-exists-p filename)
	(progn 
	  (setq new-filename
		(concat (file-name-sans-extension filename)
			"-" (number-to-string num)))
	  (while (file-exists-p (concat new-filename ".pdf"))
	    (setq num (+ num 1))
	    (setq new-filename
		  (concat (file-name-sans-extension filename)
			  "-" (number-to-string num))))
	  (setq filename (concat new-filename ".pdf")))
      filename)))


(provide 'qpdf.el)
;;; qpdf.el ends here
