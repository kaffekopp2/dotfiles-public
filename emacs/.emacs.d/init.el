
(let ((trustfile
       (cond
	((eq system-type 'gnu/linux)
	 (if (string-match "\\.el7\\." operating-system-release)
	     "/etc/pki/tls/certs/ca-bundle.crt"	   ;; centos
	   "/etc/ssl/certs/ca-certificates.crt"))  ;; ubuntu
	(t "/usr/local/etc/openssl/cert.pem"))))   ;; darwin
  ;; https://curl.se/docs/caextract.html
  (setq tls-checktrust t)
  (setq tls-program
	(list
	 (format "gnutls-cli --x509cafile %s -p %%p %%h" trustfile)))
  (setq gnutls-verify-error t)
  (setq gnutls-trustfiles (list trustfile)))
; https://glyph.twistedmatrix.com/2015/11/editor-malware.html
; http://elpa.gnu.org/packages/gnu-elpa-keyring-update.html

(setq load-prefer-newer t)

;; ----------------------------------------------------------------------------
;;| Package
;; ----------------------------------------------------------------------------

(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/"))

;; ----------------------------------------------------------------------------
;;| Paths
;; ----------------------------------------------------------------------------

(when (and (eq system-type 'darwin)
	   (native-comp-available-p))
  (setenv "LIBRARY_PATH" (concat
			  (getenv "LIBRARY_PATH") ":"
			  (string-trim (shell-command-to-string "xcrun --sdk macosx --show-sdk-path"))
			  "/usr/lib")))

(if (eq system-type 'windows-nt)
    (let ((path "C:/cygwin64/bin;C:/windows/system32;C:/Program Files/CMake/bin"))
      (setenv "PATH" path)
      (setq exec-path (split-string path path-separator)))
  (when (display-graphic-p)
    (let ((path-from-shell (replace-regexp-in-string
			    "[[:space:]\n]*$" ""
			    (shell-command-to-string
			     (format "$SHELL %s -c 'printenv PATH'"
				     (if (string= "/bin/tcsh" (getenv "SHELL")) "" "-l"))))))
      (setenv "PATH" path-from-shell)
      (setq exec-path (split-string path-from-shell path-separator)))))

;; ----------------------------------------------------------------------------
;;| Evil mode
;; ----------------------------------------------------------------------------

(setq evil-want-integration t
      evil-want-keybinding nil)
(require 'evil)
(require 'evil-collection)
(require 'evil-leader)
(require 'evil-numbers)

(global-evil-leader-mode)
(evil-esc-mode 1)			; make C-[ escape

(add-hook 'evil-command-window-mode-hook 'evil-local-mode)

(require 'undo-tree)
(global-undo-tree-mode)

(when (fboundp 'evil-set-undo-system)
  (evil-set-undo-system 'undo-tree))
(evil-declare-ignore-repeat 'evil-undo)

(setq-default evil-ex-search-case 'sensitive)
(setq-default evil-search-module 'evil-search)

(evil-leader/set-leader "<SPC>")
(evil-leader/set-key "w" 'evil-write)

(evil-declare-ignore-repeat 'evil-scroll-line-to-center)
(evil-declare-ignore-repeat 'hscroll-cursor-left)
(evil-declare-ignore-repeat 'hscroll-cursor-right)
(evil-declare-ignore-repeat 'recenter-top-bottom)
(evil-declare-ignore-repeat 'other-window)

(setq evil-move-beyond-eol t)

(defun my-wrap-eol (func &rest args)
  "Temporarily disable evil-move-beyond-eol for evil commands,
leave it at 't' for Emacs commands"
  (if (and real-this-command
	   (symbolp real-this-command)
	   (string-match-p "^evil-" (symbol-name real-this-command)))
      (let ((evil-move-beyond-eol nil))
	(apply func args))
    (apply func args)))

(dolist (func '(evil-normal-post-command evil-eolp))
  (advice-add func :around #'my-wrap-eol))

(defun my-forward-before-insert (&rest args)
  "Move the cursor forward before closing a tag or inserting a time stamp"
  (when (and (eq evil-state 'normal)
	     (not (eolp)))
    (forward-char)))

(defun my-delete-or-indent-left ()
  (interactive)
  (if (eolp)
      (evil-shift-left-line 1)
    (delete-char 1)))
(evil-global-set-key 'insert (kbd "C-d") 'my-delete-or-indent-left)

;; fall through to emacs keys, C/M-f/b and M-d M-m already works in insert mode
(define-key evil-normal-state-map (kbd "M-.") nil)
(define-key evil-normal-state-map (kbd "M-,") nil)
(define-key evil-visual-state-map (kbd "C-w") 'kill-region)
(evil-global-set-key 'normal (kbd "C-t") nil)
(evil-global-set-key 'motion (kbd "C-a") nil)
(evil-global-set-key 'insert (kbd "C-a") nil)
(evil-global-set-key 'insert (kbd "C-e") nil)
(evil-global-set-key 'insert (kbd "C-k") nil)
(evil-global-set-key 'insert (kbd "C-y") nil)
(evil-global-set-key 'insert (kbd "C-n") nil)
(evil-global-set-key 'insert (kbd "C-p") nil)
(evil-global-set-key 'insert (kbd "C-o") nil)

(define-key evil-ex-completion-map (kbd "C-a") 'move-beginning-of-line)
(define-key evil-ex-completion-map (kbd "C-f") 'forward-char)
(define-key evil-ex-completion-map (kbd "C-b") 'backward-char)
(define-key evil-ex-completion-map (kbd "C-k") 'kill-line)

(evil-global-set-key 'insert   (kbd "C-c") 'evil-normal-state)
(evil-global-set-key 'visual   (kbd "C-c") 'evil-normal-state)
(evil-global-set-key 'operator (kbd "C-c") 'evil-normal-state)
(evil-global-set-key 'replace  (kbd "C-c") 'evil-normal-state)

(evil-global-set-key 'normal (kbd "C-a") 'evil-numbers/inc-at-pt)
(evil-global-set-key 'normal (kbd "C-p") 'evil-numbers/dec-at-pt)
(evil-global-set-key 'normal (kbd "g C-a") 'evil-numbers/inc-at-pt-incremental)
(evil-global-set-key 'normal (kbd "g C-p") 'evil-numbers/dec-at-pt-incremental)

;; ----------------------------------------------------------------------------
;;| Syntax and indent
;; ----------------------------------------------------------------------------

(defun my-syntax-entry ()
  ;; - + are punctuation
  (modify-syntax-entry ?- ".")
  (modify-syntax-entry ?+ ".")
  ;; / is punctuation, so evil * works on path components
  (modify-syntax-entry ?/ ".")
  (modify-syntax-entry ?| ".")
  ;; _ is word constituent
  (modify-syntax-entry ?_ "w"))

(setq-default sentence-end-double-space nil)
(setq-default fill-column 70)      ; set tw=70
(setq-default truncate-lines t)    ; set nowrap
(setq-default tab-width 8)         ; set ts=8
(setq-default evil-shift-width 8)
(setq-default indent-tabs-mode t)  ; set noexpandtab
(setq-default align-to-tab-stop nil) ; tabs+spaces instead of all tabs
(setq-default tab-always-indent nil)

(electric-indent-mode 1)

;; ----------------------------------------------------------------------------
;;| Find file
;; ----------------------------------------------------------------------------

(setq my-input-method nil)

(defun my-find-file-hook ()
  (if (file-remote-p (buffer-file-name))
      (setq-local vc-handled-backends nil))
  (when (not (or (eq major-mode 'image-mode)
		 (derived-mode-p 'bongo-mode)))
    (setq-local show-trailing-whitespace t)
    (evil-local-mode 1)
    (when (and git-commit-mode (looking-at "^$"))
      (evil-insert-state)))
  (if my-input-method
      (set-input-method my-input-method)))

(add-hook 'find-file-hook 'my-find-file-hook)

(with-eval-after-load "tramp"
  (setq remote-file-name-inhibit-locks t))

;; ----------------------------------------------------------------------------
;;| Find file at point
;; ----------------------------------------------------------------------------

(defun my-find-file-at-point ()
  "If the file at the point exists, open it instead of prompting"
  (interactive)
  (let ((name (catch 'my-ffap-catch
		(ffap-file-at-point))))
    (if (ffap-file-exists-string name)
	(find-file name)
      (call-interactively 'find-file-at-point))
    (let ((file (buffer-file-name)))
      (when file
	(princ file)))))

(defun my-ffap-match-non-existent (name)
  "Added at the end of the ffap-alist to throw a non-existent file"
  (throw 'my-ffap-catch name))

(with-eval-after-load "ffap"
  (add-to-list 'ffap-alist '("." . my-ffap-match-non-existent) t))

(evil-global-set-key 'normal (kbd "gf") 'my-find-file-at-point)
(global-set-key (kbd "C-c f") #'my-find-file-at-point)

;; ----------------------------------------------------------------------------
;;| Convenience
;; ----------------------------------------------------------------------------

(defalias 'yes-or-no-p 'y-or-n-p)

;; (column-number-mode t)

(show-paren-mode)
(setq-default
 show-paren-when-point-inside-paren t
 show-paren-when-point-in-periphery t)

(defun my-insert-enter-hook ()
  (show-paren-mode -1))
(defun my-insert-exit-hook ()
  (show-paren-mode 1))
(add-hook 'evil-insert-state-entry-hook 'my-insert-enter-hook)
(add-hook 'evil-insert-state-exit-hook 'my-insert-exit-hook)

(blink-cursor-mode -1)
(setq-default cursor-type 'box)

(setq next-error-highlight-no-select t) ;; leave highlight for occur
(setq ring-bell-function 'ignore) ;; stop binging noise on C-g
(setq register-preview-delay 0.5)

(setq-default vc-follow-symlinks t)
(setq-default backup-inhibited t)    ;; disable backup
(setq-default auto-save-default nil) ;; disable auto save

(recentf-mode 1)
(save-place-mode 1)
(setq save-place-forget-unreadable-files nil)
(setq history-length 1000)
(setq history-delete-duplicates t)
(savehist-mode 1)

(when (not (version< emacs-version "28.1"))
  (setq-default bookmark-set-fringe-mark nil))

(put 'narrow-to-region 'disabled nil)

(when (display-graphic-p)
  (tool-bar-mode -1)
  (scroll-bar-mode -1))

(when (not (eq system-type 'darwin))
  (menu-bar-mode -1))


(require 'thingatpt)

(defun my-substitute (&optional range)
  (interactive)
  (let* ((sym (thing-at-point 'symbol t))
	 ;; want @ by default so dabbrev-expand works
	 (delim (if (string-match-p "@" sym) "#" "@")))
    (evil-ex (format "%ss%s\\_<%s\\_>%s" (or range "%") delim sym delim))))

(defun my-delete-whitespace (&optional prefix)
  (interactive "P")
  (if (region-active-p)
      (progn
	(call-interactively 'delete-trailing-whitespace)
	(deactivate-mark)
	(message "Deleted trailing whitespace"))
    (delete-horizontal-space prefix)))

(defun my-copy-filename ()
  (interactive)
  (let ((x (or (buffer-file-name) default-directory)))
    (kill-new x)
    (message "Yanked %s" x)))

(defun my-mirror-buffer ()
  "Mirror current buffer to other window"
  (interactive)
  (when (= 1 (count-windows))
    (split-window-right))
  (let ((buf (current-buffer))
	(line (line-number-at-pos)))
    (save-selected-window
      (other-window 1)
      (switch-to-buffer buf)
      (goto-line line)
      (recenter-top-bottom))))

(defun my-close-other-window ()
  (interactive)
  (quit-window nil (next-window)))

(defun my-jump-buffer (name)
  (interactive)
  (let ((w (get-buffer-window name)))
      (if w
	  (select-window w)
	(switch-to-buffer name))))

(defun my-join-line ()
  (interactive)
  (join-line 1))

(defun my-mark-until-whitespace ()
  "Select until the next whitespace char"
  (interactive)
  (when (looking-at "[^[:space:]\n]+")
    (push-mark (match-end 0) nil t)))

(evil-leader/set-key "s" #'my-substitute) ; substitute whole buffer
(evil-leader/set-key "S" ; substitute from current line to end of buffer
  (lambda ()
    (interactive)
    (my-substitute ".,$")))

(evil-leader/set-key "%" #'my-copy-filename)
(evil-leader/set-key "=" #'align-regexp)
(evil-leader/set-key "m" #'my-mirror-buffer)
(evil-leader/set-key "d" 'pwd)
(evil-leader/set-key "SPC" (kbd "=i{"))

(when (eq system-type 'gnu/linux)
  (evil-global-set-key 'motion (kbd "K") 'man))

(when (eq system-type 'darwin)
  ;; skip slow vertico minibuffer prompt for man pages
  (evil-global-set-key 'motion (kbd "K") (lambda ()
					   (interactive)
					   (man (thing-at-point 'word t))))
  ;; completion list for man pages is slow
  (defun my-advise-man-completion (&rest args) '())
  (advice-add #'Man-completion-table :override #'my-advise-man-completion))

(global-set-key (kbd "C-c j") #'goto-last-change)
(global-set-key (kbd "C-c q") #'my-close-other-window)
(global-set-key (kbd "C-c u") #'toggle-truncate-lines)
(global-set-key (kbd "C-c i") (lambda ()
				(interactive)
				(find-file user-init-file)))
(global-set-key (kbd "C-c SPC") 'my-mark-until-whitespace)
(global-set-key (kbd "C-c w") 'evil-window-map)

(require 'expand-region)
(global-set-key (kbd "C-M-o") 'er/expand-region)

(winner-mode 1)
(global-set-key (kbd "M-=") 'winner-undo)
(global-set-key (kbd "M-+") 'winner-redo)

(global-set-key (kbd "M-z") 'zap-up-to-char)
(global-set-key (kbd "M-o") (kbd "C-x o"))
(global-set-key (kbd "M-j") #'my-join-line)
(global-set-key (kbd "M-'") #'delete-blank-lines)
(global-set-key (kbd "M-\\") #'my-delete-whitespace)

(push 'try-expand-line hippie-expand-try-functions-list)
(evil-global-set-key 'insert (kbd "C-x C-l") 'hippie-expand) ;; line completion like vim

(global-set-key (kbd "C-h C-c") nil)
(global-set-key (kbd "C-x w") 'subword-mode)

(evil-leader/set-key "li" #'flyspell-mode)
(evil-leader/set-key "lb" #'flyspell-buffer)
(evil-leader/set-key "ls" #'ispell)

(defun my-advise-comment (&rest args)
  (when (evil-normal-state-p)
    (call-interactively 'evil-append)))

(advice-add 'comment-dwim :after 'my-advise-comment)

(when (not (display-graphic-p))
  (global-set-key (kbd "C-x ;") (kbd "C-x C-;")))

;; https://stackoverflow.com/a/998472
(defun p/duplicate-line (arg)
  "Duplicate current line, leaving point in lower line."
  (interactive "*p")
  ;; save the point for undo
  (setq buffer-undo-list (cons (point) buffer-undo-list))
  ;; local variables for start and end of line
  (let ((bol (save-excursion (beginning-of-line) (point)))
        eol)
    (save-excursion
      ;; don't use forward-line for this, because you would have
      ;; to check whether you are at the end of the buffer
      (end-of-line)
      (setq eol (point))
      ;; store the line and disable the recording of undo information
      (let ((line (buffer-substring bol eol))
            (buffer-undo-list t)
            (count arg))
        ;; insert the line arg times
        (while (> count 0)
          (newline)         ;; because there is no newline in 'line'
          (insert line)
          (setq count (1- count))))
      ;; create the undo information
      (setq buffer-undo-list (cons (cons eol (point)) buffer-undo-list))))
  ;; put the point in the lowest line and return
  (next-line arg))

(global-set-key (kbd "C-M-y") 'p/duplicate-line)

;; ----------------------------------------------------------------------------
;;| Help
;; ----------------------------------------------------------------------------

(require 'which-key)
(which-key-mode)

(with-eval-after-load "help"
  (define-key help-mode-map (kbd "C-w") 'evil-window-map)
  (define-key help-mode-map (kbd "SPC") evil-leader--default-map))

(with-eval-after-load "info"
  (define-key Info-mode-map (kbd "C-w") 'evil-window-map)
  (define-key Info-mode-map (kbd "SPC") evil-leader--default-map))

(with-eval-after-load "man"
  (define-key Man-mode-map (kbd "C-w") 'evil-window-map)
  (define-key Man-mode-map (kbd "SPC") evil-leader--default-map))

;; ----------------------------------------------------------------------------
;;| Abbreviations
;; ----------------------------------------------------------------------------

(setq save-abbrevs nil)
(define-global-abbrev "retrun" "return")
(define-global-abbrev "cosnt" "const")
(define-global-abbrev "conat" "const")
(define-global-abbrev "trinagle" "triangle")

(defun my-abbrev-expand ()
  "Don't expand in strings or comments"
  (if (not (nth 8 (syntax-ppss)))
      (abbrev--default-expand)))

(defun my-prog-mode-hook ()
  (abbrev-mode)
  (setq-local show-trailing-whitespace t)
  (setq-local fill-column 80)
  (setq-local abbrev-expand-function #'my-abbrev-expand))

(add-hook 'prog-mode-hook #'my-prog-mode-hook)

(add-hook 'text-mode-hook #'abbrev-mode)

;; ----------------------------------------------------------------------------
;;| Fancy dabbrev
;; ----------------------------------------------------------------------------

(require 'fancy-dabbrev)

(global-fancy-dabbrev-mode)

(global-set-key (kbd "M-/") 'fancy-dabbrev-expand)
(global-set-key (kbd "<backtab>") 'fancy-dabbrev-backward)
(setq-default fancy-dabbrev-menu-height 15)
(setq-default fancy-dabbrev-preview-context 'everywhere)
(setq-default fancy-dabbrev-preview-delay 0.15)
;; (push 'evil-input-method fancy-dabbrev-no-preview-for)

(define-key minibuffer-local-map (kbd "M-/") 'dabbrev-expand)

;; ----------------------------------------------------------------------------
;;| Lang
;; ----------------------------------------------------------------------------

(defun my-cpp-identifier-around-point ()
  (let* ((regex "\\(\\s-\\|[^[:alnum:]_:]\\)")
	 (beg (save-excursion
		(if (re-search-backward regex (pos-bol) t)
		    (when (looking-at regex)
		      (forward-char))
		  (move-beginning-of-line 1))
		(point)))
	 (end (save-excursion
		(if (re-search-forward regex (pos-eol) t)
		    (backward-char)
		  (move-end-of-line 1))
		(point)))
	 (sym (buffer-substring-no-properties beg end)))
    (if (string-empty-p sym) nil sym)))

(defun my-lookup ()
  (interactive)
  (let* ((google "https://www.google.com/search?ie=utf-8&oe=utf-8&q=")
	 (translate (let ((input-method (if (or (not (bound-and-true-p evil-local-mode))
						(evil-emacs-state-p))
					    current-input-method
					  evil-input-method)))
		      (cond
		       ((string= input-method "swedish-postfix") "https://translate.google.com/?sl=sv&tl=en&op=translate&text=")
		       ((string= input-method "german-postfix") "https://translate.google.com/?sl=de&tl=en&op=translate&text=")
		       (t nil)))))

    (browse-url
     (if mark-active
	 (let ((text (buffer-substring-no-properties (region-beginning) (region-end))))
	   (cond
	    (translate (concat translate (url-hexify-string (read-string "Translate: " text))))
	    (t (concat google (url-hexify-string (format "\"%s\"" (read-string "Search Google: " text)))))))

       (let* ((cc (or (eq major-mode 'c++-mode)
		      (eq major-mode 'c-mode)))
	      (sym (if cc
		       (my-cpp-identifier-around-point)
		     (thing-at-point 'symbol t))))
	 (cond
	  ((and cc sym (string-match-p "^gl[A-Z][^\s-]+$" sym))
	   (concat "https://docs.gl/" (read-string "OpenGL: " (concat "gl4/" sym))))
	  ((and cc sym (string-match-p "^Q[^\s-]+$" sym))
	   (format "https://doc.qt.io/qt-5/%s.html" (downcase (read-string "Qt: " sym))))
	  ((and cc sym (string-match-p "^M[A-Z][^\s-]+$" sym))
	   (format "https://help.autodesk.com/view/MAYAUL/2020/ENU/?query=%s&cg=Developer%%27s%%20Documentation"
		   (read-string "Maya API: " sym)))
	  ((and cc sym)
	   (concat google (url-hexify-string
			   (format "%s site:cppreference.com"
				   (read-string "Search cppreference: " sym)))))
	  (translate (concat translate (url-hexify-string (read-string "Translate: " sym))))
	  (t (concat google (url-hexify-string (read-string "Search Google: " sym))))))))))

(global-set-key (kbd "M-s M-w") #'my-lookup)

;; ----------------------------------------------------------------------------
;;| Keyboard
;; ----------------------------------------------------------------------------

(when (eq system-type 'darwin)
  ;; tilde in the same place as in US keyboard
  (keyboard-translate ?\§ ?\`)
  (keyboard-translate ?\± ?\~)

  (setq-default mac-command-modifier 'meta)
  (setq-default mac-right-command-modifier 'control)
  (setq-default mac-option-modifier 'alt))

;; ----------------------------------------------------------------------------
;;| Clipboard
;; ----------------------------------------------------------------------------

(defun my-copy-to-xclipboard ()
  (interactive)
  (call-process-region (region-beginning) (region-end) "xsel" nil nil nil "-ib")
  (message "Yanked region"))

(when (eq system-type 'gnu/linux)
  (global-set-key (kbd "C-c y") 'my-copy-to-xclipboard)
  (evil-global-set-key 'visual (kbd "Y") 'my-copy-to-xclipboard))

;; ----------------------------------------------------------------------------
;;| Scrolling
;; ----------------------------------------------------------------------------

;; stop scrolling to centre when cursor is on first/last line and
;; moves up/down
(setq-default scroll-up-aggressively 0.0)
(setq-default scroll-down-aggressively 0.0)

(setq-default auto-hscroll-mode 't
	      hscroll-margin 5
	      hscroll-step 5)

;; ----------------------------------------------------------------------------
;;| Text
;; ----------------------------------------------------------------------------

(defun my-after-evil-buffer-new (&rest args)
  (let ((buffer (window-buffer)))
    (when buffer
      (with-current-buffer buffer
	(my-syntax-entry)
	(evil-local-mode)))))

;;; after :enew
(advice-add 'evil-buffer-new :after #'my-after-evil-buffer-new)

(defun my-text-mode-hook ()
  (turn-on-auto-fill)
  (my-syntax-entry)
  (when (not (buffer-file-name))
    (evil-local-mode)))

(add-hook 'text-mode-hook 'my-text-mode-hook)

;; ----------------------------------------------------------------------------
;;| Message
;; ----------------------------------------------------------------------------

(defun my-scratch-message-buffer ()
  (interactive)
  (let ((buf (generate-new-buffer "untitled")))
    (switch-to-buffer buf)
    (setq buffer-offer-save t)
    (message-mode)))

(defun my-message-mode-hook ()
  (my-syntax-entry)
  ;; = is punctuation, so evil * works on key and val separately for key=val
  (modify-syntax-entry ?= ".")
  (setq-local show-trailing-whitespace t)
  (setq-local fill-column 72)
  ;; stop paragraph lines after the first being extra indented by M-q
  (setq-local fill-paragraph-function nil))

(add-hook 'message-mode-hook 'my-message-mode-hook)

(with-eval-after-load "message"
  (define-key message-mode-map (kbd "C-c C-c") nil)
  (define-key message-mode-map (kbd "C-c C-s") nil))

(setq-default message-auto-save-directory nil)

(setq compose-mail-user-agent-warnings nil)

(global-set-key (kbd "C-x m") #'my-scratch-message-buffer)

;; ----------------------------------------------------------------------------
;;| Calendar
;; ----------------------------------------------------------------------------

(setq-default calendar-week-start-day 1) ;; start on monday

(push '("\\*Calendar\\*"
        (display-buffer-reuse-window display-buffer-below-selected)
        (window-height . 10))
      display-buffer-alist)

(global-set-key (kbd "C-c M-c") 'calendar)

;; ----------------------------------------------------------------------------
;;| Org
;; ----------------------------------------------------------------------------

;;; override org version. 9.6 randomly fails to display tasks scheduled for the
;;; current day in the agenda.
(add-to-list 'load-path "~/dev/org-mode/lisp")

;;; move slowdown to startup instead of when opening an org file
(require 'org)

(when (eq system-type 'gnu/linux)
  (setq org-agenda-files (list "~/notes.org"))
  (setq org-default-notes-file "~/notes.org"))
(when (eq system-type 'darwin)
  (setq org-agenda-files (list "~/notes.org.gpg"))
  (setq org-default-notes-file "~/notes.org.gpg"))

(setq org-directory "~/org")
(setq org-log-done t)
(setq org-agenda-start-on-weekday nil)
(setq org-agenda-restore-windows-after-quit t)
(setq org-agenda-search-view-always-boolean t)
(setq org-html-validation-link nil)
(setq org-publish-use-timestamps-flag nil)
(setq org-catch-invisible-edits 'smart)
(setq org-cycle-separator-lines 0)
(setq org-src-fontify-natively t)
(setq org-startup-folded nil)
(setq org-confirm-babel-evaluate nil)
(setq org-todo-keywords '((sequence "TODO(t)" "WAIT(w@)" "|" "DONE(d)")
			  (sequence "|" "CANCELLED(c@)")))

(setq org-capture-templates
      '(("k" "Bookmark" entry (file+headline org-default-notes-file "Bookmarks")
	 "* %?\n")
	("x" "Task" entry (file+headline org-default-notes-file "Tasks")
	 "* TODO %?\nSCHEDULED: %t\n:PROPERTIES:\n:CREATED: %U\n:END:\n")))

(when (eq system-type 'darwin)
    (push '("b" "Book" entry (file+headline org-default-notes-file "Books")
	    "* %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n")
	  org-capture-templates)
    (push '("r" "Read/watch" entry (file+headline org-default-notes-file "Tasks")
	    "* %? :READ:\n:PROPERTIES:\n:CREATED: %U\n:END:\n")
	  org-capture-templates)
    (push '("p" "Project" entry (file+headline org-default-notes-file "Tasks")
	    "* %? :PROJECT:\n:PROPERTIES:\n:CREATED: %U\n:END:\n")
	  org-capture-templates))

(setq my-org-agenda-common-review-settings
      '((org-agenda-show-all-dates t)
	(org-agenda-start-with-log-mode t)
	(org-agenda-start-with-clockreport-mode t)
	;; https://orgmode.org/manual/Special-Agenda-Views.html
	(org-agenda-skip-function '(org-agenda-skip-entry-if 'todo '("TODO" "WAITING")))
	(org-agenda-archives-mode t)
	(org-agenda-clockreport-parameter-plist '(:link t :hidefiles t :tags t :step day :maxlevel 2 :fileskip0 t :formula %))
	;; (org-agenda-hide-tags-regexp
	;;  (concat org-agenda-hide-tags-regexp "\\|ARCHIVE"))
	(org-agenda-start-on-weekday 1)))

(let ((tag (if (eq system-type 'darwin) "READ|PROJECT")))
  (setq org-agenda-custom-commands
	`(("d" "Done stuff" todo "DONE" )
	  ("n" "Agenda and all TODOs" ((agenda "") (alltodo "")))
	  ("g" ,(format "Agenda and %s" tag)
	   ((agenda "" )
	    ,@(if (eq system-type 'gnu/linux) '((tags "PIN")))
	    (todo "TODO|WAIT" ((org-agenda-overriding-header "Unscheduled TODO|WAIT:")
			  (org-agenda-skip-function
			   '(org-agenda-skip-entry-if 'scheduled 'deadline))
			  (org-agenda-sorting-strategy
			   '((todo priority-down alpha-up)))))
	    ,@(if tag
		  `((tags ,tag ((org-agenda-skip-function
				 '(org-agenda-skip-entry-if 'todo '("DONE")))
				(org-agenda-sorting-strategy
				 '((tags tag-up alpha-up))))))))
	   ((org-agenda-start-with-log-mode nil)
	    (org-tags-match-list-sublevels nil)))
	  ("w" "This week"
	   agenda ""
	   ,(append my-org-agenda-common-review-settings
		    '((org-agenda-span 'week)
		      (org-agenda-overriding-header "Week in Review")))
	   ("/tmp/week.html"))
	  ("W" "Last week"
	   agenda ""
	   ,(append my-org-agenda-common-review-settings
		    '((org-agenda-span 'week)
		      (org-agenda-start-day "-1w")
		      (org-agenda-overriding-header "Last week in Review")))
	   ("/tmp/lastweek.html")))))

(defun my-org-shift (left)
  (if (string-match-p "^[\s-]*[*-] " (thing-at-point 'line))
      (if left
	  (if (eolp)
	      (org-metaleft)
	    (delete-char 1))
	(org-metaright))
    (if left
	(my-delete-or-indent-left)
      (evil-shift-right-line 1))))

(defun my-org-mode-hook ()
  ;; override the evil binding of C-i (jump forward), as C-i is the
  ;; same as tab in the terminal, which we want in org mode for
  ;; (un)collapsing headers
  (when (not (display-graphic-p))
    (evil-local-set-key 'motion (kbd "C-i") 'org-cycle))
  (when (and (display-graphic-p)
	     (not (version< emacs-version "28.1")))
    (evil-local-set-key 'normal (kbd "TAB") 'org-cycle))

  (evil-local-set-key 'normal (kbd "[[") #'org-toggle-link-display)
  (evil-local-set-key 'insert (kbd "<backtab>") #'fancy-dabbrev-backward)
  (evil-local-set-key 'insert (kbd "C-t") (lambda () (interactive) (my-org-shift nil)))
  (evil-local-set-key 'insert (kbd "C-d") (lambda () (interactive) (my-org-shift t)))
  (evil-local-set-key 'insert (kbd "TAB") (lambda (&optional prefix)
					    (interactive "P")
					    (if prefix
						(insert-tab prefix)
					      (org-cycle))))

  ;; / is punctuation, so evil * works on path components
  (modify-syntax-entry ?/ ".")
  (auto-fill-mode 1)
  (setq-local indent-tabs-mode nil)
  (setq-local evil-shift-width 2)
  (setq-local tab-width 2))

(defun my-org-capture-hook ()
  (interactive)
  (my-org-mode-hook)
  (evil-insert-state))

(defun my-org-src-hook ()
  (evil-local-mode 1))

(add-hook 'org-mode-hook 'my-org-mode-hook)
(add-hook 'org-capture-mode-hook 'my-org-capture-hook)
(add-hook 'org-src-mode-hook 'my-org-src-hook)

(defun my-org-clock-jump ()
  (interactive)
  (push-mark (point))
  (org-clock-jump-to-current-clock))

(defun my-www-get-page-title (url)
  (with-current-buffer (url-retrieve-synchronously url)
    (goto-char (point-min))
    (re-search-forward "<title[^>]*>\\([^<]*\\)</title>" nil t 1)
    (let ((title (match-string 1)))
      (goto-char (point-min))
      (re-search-forward "charset=\\([-0-9a-zA-Z]*\\)" nil t 1)
      (let* ((c (match-string 1))
	     (coding (if (or (not c)
			     (string= c "UTF-8")
			     (string= c title))
			 "utf-8" c)))
	(decode-coding-string title (intern coding))))))

(defun my-wrap-org-link ()
  "With point at the start of a URL, turn it into [[url][title]]"
  (interactive)
  (let* ((url (thing-at-point 'url t))
	 (title (my-www-get-page-title url)))
    (save-excursion
      (insert "[[")
      (evil-forward-WORD-end)
      (forward-char)
      (insert (format "][%s]]" title)))))

(defun my-insert-org-src-block  ()
  "Insert a src block with the same language as the previous block"
  (interactive)
  (let ((lang (save-excursion
		(org-babel-previous-src-block)
		(move-end-of-line 1)
		(thing-at-point 'word t))))
    (org-insert-structure-template (format "src %s" lang))))

(defun my-goto-random-line ()
  (interactive)
  (goto-line (+ 1 (random
		   (+ 1 (save-excursion
			  (goto-char (point-max))
			  (current-line))))))
  (recenter nil t))

(advice-add 'org-time-stamp-inactive :before #'my-forward-before-insert)

(with-eval-after-load 'org-agenda
  (define-key org-agenda-mode-map (kbd "C-w") 'evil-window-map))

(with-eval-after-load 'org
  (define-key org-mode-map (kbd "C-j") nil)
  (define-key org-mode-map (kbd "C-c C-j") nil)
  (define-key org-mode-map (kbd "C-c [") 'org-toggle-link-display)

  (org-babel-do-load-languages 'org-babel-load-languages
			       '((shell . t)
				 (awk . t)
				 (python .t)
				 (emacs-lisp . t)
				 (gnuplot . t)))

  (defun my-update-inline-images ()
    (when org-inline-image-overlays
      (org-redisplay-inline-images)))

  (add-hook 'org-babel-after-execute-hook 'my-update-inline-images)

  (when (eq system-type 'darwin)
    (setq org-babel-python-command "python3")
    ;; for pdf export
    (require 'ox-pandoc)))

(global-set-key (kbd "C-'") 'org-cycle-agenda-files)
(global-set-key (kbd "C-c l") 'org-store-link)
(global-set-key (kbd "C-c a") 'org-agenda)
(global-set-key (kbd "C-c x") 'org-capture)
(global-set-key (kbd "C-c M-t") #'my-wrap-org-link)
(global-set-key (kbd "C-c C-x C-j") 'my-org-clock-jump)

(evil-leader/set-key "g" (lambda ()
			   (interactive)
			   (org-agenda nil "g")))

(evil-leader/set-key-for-mode 'org-mode "," 'org-insert-structure-template)
(evil-leader/set-key-for-mode 'org-mode "c" 'my-insert-org-src-block)
(evil-leader/set-key-for-mode 'org-mode "SPC" 'my-goto-random-line)

;; ----------------------------------------------------------------------------
;;| Ledger
;; ----------------------------------------------------------------------------

(when (eq system-type 'darwin)
  (setq ledger-binary-path (expand-file-name "~/dotfiles-public/bin/ledger.bash")))

;; ----------------------------------------------------------------------------
;;| Calc
;; ----------------------------------------------------------------------------

(with-eval-after-load "calc-ext"
  (define-key calc-mode-map (kbd "C-c e")   #'calc-reset)
  (define-key calc-mode-map (kbd "C-c C-e") #'calc-reset)
  (setq calc-multiplication-has-precedence nil)
  (setq calc-make-windows-dedicated t)
  (advice-add #'calc-user-define-formula :around #'my-disable-vertico))

(defun my-calc-hook ()
  (calc-trail-display 0))

(add-hook 'calc-mode-hook 'my-calc-hook)

(setq calc-angle-mode 'rad)

(defun my-calc-yank ()
  "Yank number at point into calc stack"
  (interactive)
  (save-excursion
    (when (looking-at "[[:space:]]")
      (re-search-forward "[^[:space:]]"))
    (calc-yank-internal nil (format "%s" (number-at-point)))))

(global-set-key (kbd "C-x C-y") 'my-calc-yank)

;; ----------------------------------------------------------------------------
;;| Browser
;; ----------------------------------------------------------------------------

(when (eq system-type 'gnu/linux)
  ;; open org links in chrome
  (setq browse-url-browser-function 'browse-url-generic)
  (setq browse-url-generic-program "google-chrome"))

(setq org-file-apps '((auto-mode . emacs)
		      (directory . emacs)
		      ("\\.mm\\'" . default)
		      ("\\.x?html?\\'" . "google-chrome %s")
		      ("\\.pdf\\'" . default)))

;; ----------------------------------------------------------------------------
;;| HTML
;; ----------------------------------------------------------------------------

(defun my-html-hook ()
  (define-key html-mode-map (kbd "M-o") nil)
  (evil-local-set-key 'normal (kbd "gb")
		      (lambda ()
			(interactive)
			(save-buffer)
			(browse-url-of-file))))

(add-hook 'html-mode-hook #'my-html-hook)

(advice-add 'sgml-close-tag :before #'my-forward-before-insert)

;; ----------------------------------------------------------------------------
;;| Vertico
;; ----------------------------------------------------------------------------

(require 'vertico)
(require 'vertico-directory)
(vertico-mode)

(setq vertico-count-format nil)
(setq vertico-group-format nil)

(define-key vertico-map (kbd "DEL") #'vertico-directory-delete-char)
(define-key vertico-map (kbd "C-j") nil)
(define-key vertico-map (kbd "C-h f")
  (lambda ()
    (interactive)
    (describe-function (intern (vertico--candidate)))))

(defun my-disable-vertico (func &rest args)
  (let ((v vertico-mode))
    (vertico-mode 0)
    (unwind-protect
	(apply func args)
      (vertico-mode v))))

;; ----------------------------------------------------------------------------
;;| Marginalia
;; ----------------------------------------------------------------------------

(require 'marginalia)
(marginalia-mode)

(defun my-disable-marginalia (func &rest args)
  (let ((m marginalia-mode))
    (marginalia-mode 0)
    (unwind-protect
	(apply func args)
      (marginalia-mode m))))

;; ----------------------------------------------------------------------------
;;| Orderless
;; ----------------------------------------------------------------------------

(require 'orderless)
(setq completion-styles '(orderless flex))

;; ----------------------------------------------------------------------------
;;| Consult
;; ----------------------------------------------------------------------------

(require 'consult)

(global-set-key (kbd "C-x f") 'consult-recent-file)

(define-key minibuffer-local-map (kbd "C-r") 'consult-history)

(setq consult-preview-key nil)	; stop preview when any key is pressed
(consult-customize consult-theme :preview-key "C-j")
;; (consult-customize consult-line :preview-key 'any)

;; ----------------------------------------------------------------------------
;;| Completion
;; ----------------------------------------------------------------------------

(setq completion-ignore-case t)
(setq completion-show-help nil)

;; Don't want marginalia in *Completions* buffer when hitting TAB in
;; shell mode. Completion candidates are in a grid, and some are
;; pushed off-screen.
(advice-add #'completion--in-region :around #'my-disable-marginalia)
(advice-add #'minibuffer-complete :around #'my-disable-marginalia)

;;; popup the completion buffer at the bottom
(push '("\\*Completions\\*"
        (display-buffer-reuse-window display-buffer-at-bottom)
        (window-height . 10))
      display-buffer-alist)

;;; use vertico for completion-at-point, but not in shell buffers when
;;; completing file/directory names or when completing makefile targets in the
;;; minibuffer after running M-x compile
(setq completion-in-region-function
      (lambda (&rest args)
        (apply (if (and vertico-mode (not (or (derived-mode-p 'minibuffer-mode)
					      (derived-mode-p 'comint-mode))))
		   #'consult-completion-in-region
		 #'completion--in-region)
	       args)))

;; ----------------------------------------------------------------------------
;;| Buffers, Icomplete
;; ----------------------------------------------------------------------------

(setq read-buffer-completion-ignore-case t)

(defun my-invoke-with-completion (func)
  (let ((v vertico-mode)
	(m marginalia-mode)
	(ic icomplete-mode)
	(icv icomplete-vertical-mode))
    (vertico-mode 0)
    (marginalia-mode 0)
    (icomplete-vertical-mode -1)
    (icomplete-mode 1)
    (unwind-protect
	(call-interactively func)
      (icomplete-mode -1)
      (when v (vertico-mode 1))
      (when m (marginalia-mode 1))
      (when icv (icomplete-vertical-mode 1)))))

(defun my-kill-buffer ()
  (interactive)
  (if (buffer-modified-p)
      (my-invoke-with-completion #'kill-buffer)
    (kill-this-buffer)))

(defun my-switch-buffer ()
  (interactive)
  (my-invoke-with-completion #'switch-to-buffer))

(defun my-switch-buffer-other-window ()
  (interactive)
  (my-invoke-with-completion #'switch-to-buffer-other-window))

(evil-global-set-key 'motion (kbd "C-w d")   'my-kill-buffer)
(evil-global-set-key 'motion (kbd "C-w C-d") 'my-kill-buffer)
(global-set-key (kbd "C-x k") 'my-kill-buffer)

(global-set-key (kbd "C-j")     'my-switch-buffer)
(global-set-key (kbd "C-x b")   'my-switch-buffer)
(global-set-key (kbd "C-x 4 b") 'my-switch-buffer-other-window)
(global-set-key (kbd "C-x C-b") 'ibuffer)

(with-eval-after-load 'ibuffer
  (define-key ibuffer-mode-map (kbd "M-o") nil))

(defun my-icomplete-hook ()
  (let ((inhibit-message t))
    (toggle-truncate-lines 1)))
(add-hook 'icomplete-minibuffer-setup-hook 'my-icomplete-hook)

(setq icomplete-compute-delay 0.0)
(setq icomplete-matches-format nil)
(setq icomplete-show-matches-on-no-input t)
;; (setq completion-pcm-word-delimiters "-_./:|")
;; (setq icomplete-scroll t)
;; (icomplete-vertical-mode 1)

(with-eval-after-load 'icomplete
  (define-key icomplete-vertical-mode-minibuffer-map (kbd "RET") 'icomplete-force-complete-and-exit)
  (define-key icomplete-minibuffer-map (kbd "RET") 'icomplete-force-complete-and-exit)
  ;; (define-key icomplete-minibuffer-map (kbd "TAB") 'icomplete-force-complete)
  ;; (define-key icomplete-minibuffer-map (kbd "C-j") 'ignore)
  (define-key icomplete-minibuffer-map (kbd "SPC") 'self-insert-command) ;; allow orderless to work
  (define-key icomplete-minibuffer-map (kbd "C-j") 'icomplete-force-complete-and-exit)
  (define-key icomplete-minibuffer-map (kbd "C-s") 'icomplete-forward-completions)
  (define-key icomplete-minibuffer-map (kbd "C-r") 'icomplete-backward-completions))

;; ----------------------------------------------------------------------------
;;| Complete filenames
;; ----------------------------------------------------------------------------

(require 'cape)

(defvar my-completing-filename nil)

(defun my-complete-filename ()
  "Expand the filename before the point"
  (interactive)
  (setq my-completing-filename t)
  (unwind-protect
      (while my-completing-filename
	(call-interactively 'cape-file)
	(setq my-completing-filename (eq my-completing-filename 'continue)))
    (setq my-completing-filename nil)))

(evil-global-set-key 'insert (kbd "C-x C-f") 'my-complete-filename)

;; keep completing into directory
(define-key (if vertico-mode
		vertico-map
	      icomplete-minibuffer-map)
  (kbd "C-x C-f")
  (lambda ()
    (interactive)
    (when my-completing-filename
      (setq my-completing-filename 'continue)
      (if vertico-mode
	  (vertico-exit)
	(icomplete-force-complete-and-exit)))))

;; ----------------------------------------------------------------------------
;;| Helm
;; ----------------------------------------------------------------------------

(require 'helm)
(require 'helm-ag)
(require 'helm-occur)

(defvar my-helm-ignore '("build/"))
(defvar my-helm-ignore-extra '("*.html" "*.css" "*.ma" "glew/" "testsuite/"))

;; display relative paths in grep results
(setq-default helm-grep-file-path-style 'relative)
(setq-default helm-ag-use-grep-ignore-list t)
(setq-default helm-ag-ignore-patterns my-helm-ignore)
(setq-default helm-ag-base-command "ag --nocolor --nogroup --ignore-case --hidden")

(setq helm-highlight-only-all-matches t)
(setq helm-highlight-matches-around-point-max-lines '(25 . 25))
;;; no new frames
(setq helm-show-completion-display-function #'helm-show-completion-default-display-function)

(defun my-advise-propagate-input-method (func &rest args)
  "Allow func to use evil-input-method in minibuffer"
  (if (and (bound-and-true-p evil-local-mode)
	   evil-input-method)
      (evil-without-input-method-hooks
       (let ((input-method current-input-method))
	 (set-input-method evil-input-method)
	 (unwind-protect
	     (apply func args)
	   (set-input-method input-method))))
    (apply func args)))

(advice-add 'helm-occur :around #'my-advise-propagate-input-method)

(defun my-search-project ()
  "Search current project"
  (if (file-remote-p default-directory)
	(helm-ag-project-root)
      (helm-do-ag-project-root)))

(defun my-search (&optional prefix)
  "Search project. With prefix arg, ignore extra file types."
  (interactive "P")
  (if prefix
      (let ((helm-ag-ignore-patterns (append my-helm-ignore my-helm-ignore-extra)))
	(my-search-project))
    (my-search-project)))

(defun my-grep-project ()
  (interactive)
  (rgrep (read-string "Search for: " (format "\\<%s\\>" (thing-at-point 'symbol t)))
	 "*" (my-find-project-root)))

;;; C-c C-e in helm-ag to enter editable mode
(defun my-after-helm-ag-edit (&rest args)
  (my-syntax-entry)
  (evil-local-mode))
(advice-add #'helm-ag--edit :after #'my-after-helm-ag-edit)

(defun my-toggle-symbol-boundary (start end start-regex)
  "insert/remove start/end around search term for word/symbol boundary"
  (let (remove)
    (when (not (thing-at-point 'line))	; empty
      (next-history-element 1)
      (end-of-line))
    (save-excursion
      (beginning-of-line)
      (setq remove (looking-at start-regex)))

    (save-excursion
      (beginning-of-line)
      (if remove
	  (delete-char (length start))
	(insert start)))
    (save-excursion
      (end-of-line)
      (if remove
	  (delete-char (- (length end)))
	(insert end)))))

(define-key helm-occur-map (kbd "M-w") (lambda ()
					 (interactive)
					 (my-toggle-symbol-boundary "\\_<" "\\_>" "\\\\_<")))

(define-key helm-ag-map (kbd "M-w") (lambda ()
				      (interactive)
				      (my-toggle-symbol-boundary "\\b" "\\b" "\\\\b")))

(define-key helm-ag-map (kbd "C-c C-o") (kbd "C-c o"))

(define-key helm-map (kbd "C-c C-u") 'kill-whole-line)
(define-key helm-map (kbd "<escape>") 'helm-keyboard-quit)

(global-set-key (kbd "M-y") 'helm-show-kill-ring)
(global-set-key (kbd "C-c r") 'my-search)
(global-set-key (kbd "C-c o") 'helm-occur)
(evil-leader/set-key "r" 'my-search)
(evil-leader/set-key "o" 'helm-occur) ;; M-n grabs symbol under point
(global-set-key (kbd "M-s g") 'my-grep-project)
(global-set-key (kbd "M-s M-g") 'rgrep)

;; ----------------------------------------------------------------------------
;;| Imenu
;; ----------------------------------------------------------------------------

(defun my-imenu ()
  (interactive)
  (cond
   ((let ((f (buffer-file-name)))
      (and f (file-equal-p f user-init-file)))
    (helm-multi-occur-1 (list (current-buffer)) "^;;| "))
   ((eq major-mode 'org-mode) (consult-org-heading))
   (t (helm-imenu))))

(evil-leader/set-key "i" 'my-imenu)

;; ----------------------------------------------------------------------------
;;| Projects
;; ----------------------------------------------------------------------------

(defun my-find-project-root ()
  (let* ((dir (if (version< emacs-version "28.1")
		  (locate-dominating-file default-directory ".git")
		(let ((project (project-current nil)))
		  (and project (project-root project))))))
    (or (and dir (expand-file-name (file-name-as-directory dir)))
	default-directory)))

;; C-u opens in other window
(defun my-find-file-in-project (&optional open-in-other-window)
  (interactive "P")
  (let ((read-file-name-completion-ignore-case t))
    (if open-in-other-window
	(let* ((switch-to-buffer-obey-display-actions t)
	       (display-buffer-overriding-action '((display-buffer-pop-up-window)
						   (inhibit-same-window . t))))
	  (project-find-file))
      (project-find-file))))

(defun my-find-file-in-project-other-window ()
  (interactive)
  (let ((current-prefix-arg 4)) ;; emulate C-u
    (call-interactively 'my-find-file-in-project)))

(defun my-jump-project-dired ()
  (interactive)
  (dired (my-find-project-root)))


(defvar my-projects)
(if (eq system-type 'darwin)
    (setq my-projects '(("~/dev" . 2)))
  (setq my-projects '(("~/dev/git" . 3))))
(dolist (d '("~/dotfiles-public" "~/dotfiles" "~/notefiles" "~/.emacs.d/elpa"))
  (when (file-directory-p d)
    (push `(,d . 1) my-projects)))

(defun my-find-projects (dir depth)
  "Return a list of projects under 'dir' up to 'depth'"
  (if (string-suffix-p "/.git" dir)
      (list (string-remove-suffix "/.git" dir))
    (if (> depth 0)
	(seq-mapcat (lambda (x)
		      (my-find-projects
		       (concat dir "/" (string-remove-suffix "/" x))
		       (- depth 1)))
		    (seq-filter (lambda (x)
				  (and (string-suffix-p "/" x)
				       (not (or (string= "./" x)
						(string= "../" x)))))
				(file-name-all-completions "" dir))))))

(defun my-list-repos ()
  "Return an alist of repos, with the key the string to match
against, and the value the expanded full path to the repo"
  (let ((all '()))
    (dolist (proj my-projects)
      (let* ((dir (expand-file-name (car proj)))
	     (dir-slash (if (string-suffix-p "/" dir) dir (concat dir "/")))
	     (depth (cdr proj))
	     (repos (mapcar
		     (lambda (long)
		       (let ((short (if (string-prefix-p dir-slash long)
					(string-remove-prefix dir-slash long)
				      (file-name-nondirectory long))))
			 `(,short . ,long)))
		     (my-find-projects dir depth))))
	(setq all (nconc all repos))))
    all))

(defun my-choose-project (&optional action)
  "Choose a project then invoke action on it. If action is nil,
return the project path instead"
  (let* ((repos (my-list-repos))
	 (sel (assoc (completing-read "Repo: " repos) repos)))
    (if sel
	(let ((path (cdr sel)))
	  (if action
	      (funcall action path)
	    path)))))

(defun my-choose-project-and-invoke (func &rest args)
  "Set default-directory to the chosen project, then invoke func with args"
  (my-choose-project (lambda (path)
		       (let ((default-directory path))
			 (apply func args)
			 (pwd)))))

(defun my-choose-project-and-find-file ()
  (interactive)
  (my-choose-project-and-invoke #'my-find-file-in-project))

(defun my-choose-project-and-find-file-other-window ()
  (interactive)
  (my-choose-project-and-invoke #'my-find-file-in-project-other-window))

(defun my-choose-project-and-search (&optional prefix)
  (interactive "P")
  (my-choose-project-and-invoke (lambda ()
				  (if prefix
				      (my-search 4)
				    (my-search)))))

(defun my-choose-project-and-magit ()
  (interactive)
  (my-choose-project-and-invoke #'magit))

(defun my-choose-project-and-dired ()
  (interactive)
  (my-choose-project (lambda (path)
		       (dired path)
		       (pwd))))

(defun my-choose-project-and-shell ()
  (interactive)
  (my-choose-project-and-invoke #'project-shell))

(defun my-choose-project-and-term ()
  (interactive)
  (my-choose-project-and-invoke #'terminal-here-launch))

(defun my-jump-notefiles ()
  (interactive)
  (let ((default-directory "~/notefiles"))
    (my-find-file-in-project)))

(global-set-key (kbd "C-c p e") #'my-choose-project-and-find-file)
(global-set-key (kbd "C-c p u") #'my-choose-project-and-find-file-other-window)
(global-set-key (kbd "C-c p r") #'my-choose-project-and-search)
(global-set-key (kbd "C-c p m") #'my-choose-project-and-magit)
(global-set-key (kbd "C-c p d") #'my-choose-project-and-dired)
(global-set-key (kbd "C-c p s") #'my-choose-project-and-shell)
(global-set-key (kbd "C-c p t") #'my-choose-project-and-term)

(global-set-key (kbd "C-c e") 'my-find-file-in-project)
(global-set-key (kbd "C-x C-d") 'my-jump-project-dired)

(evil-leader/set-key "e" 'my-find-file-in-project)
(evil-leader/set-key "u" 'my-find-file-in-project-other-window)
(evil-leader/set-key "n" 'my-jump-notefiles)

;; ----------------------------------------------------------------------------
;;| Isearch
;; ----------------------------------------------------------------------------

(defun my-isearch-remove-failed-part ()
  "Remove failed part of search string, or last char if successful."
  (interactive)
  (if isearch-regexp
      (isearch-delete-char)
    (if (equal isearch-string "")
	(isearch-update)
      (if isearch-success
	  (isearch-delete-char)
	(while (isearch-fail-pos) (isearch-pop-state)))
      (isearch-update))))

(define-key isearch-mode-map (kbd "DEL") 'my-isearch-remove-failed-part)

;; space in search is a wildcard. 'M-s space' to toggle
(setq search-whitespace-regexp ".*" ; ".*?" for non-greedy
      isearch-lax-whitespace t
      isearch-regexp-lax-whitespace nil)
;; stop downcasing when symbol searching with M-s .
(setq search-upper-case t)

(defun my-isearch-hook ()
  "Use evil-input-method in isearch minibuffer"
  (when (and (bound-and-true-p evil-local-mode)
	     evil-input-method)
    (evil-without-input-method-hooks
      (set-input-method evil-input-method))))

(add-hook 'isearch-mode-hook 'my-isearch-hook)

;; ----------------------------------------------------------------------------
;;| Dired
;; ----------------------------------------------------------------------------

(require 'dired)
(require 'dired-x)
(setq dired-dwim-target t)
(put 'dired-find-alternate-file 'disabled nil)

(define-key dired-mode-map (kbd "SPC") evil-leader--default-map)
(define-key dired-mode-map (kbd "C-w") 'evil-window-map)
(define-key dired-mode-map (kbd ";") 'dired-up-directory)

(defun my-dired-hook ()
  (auto-revert-mode 1))

(add-hook 'dired-mode-hook 'my-dired-hook)

(setq-default dired-listing-switches "-alh") ;; human-readable file sizes
(when (eq system-type 'darwin)
 (setq dired-guess-shell-alist-user '(("" "open"))))

(global-set-key (kbd "C-x C-j") 'dired-jump)

;; ----------------------------------------------------------------------------
;;| Image dired
;; ----------------------------------------------------------------------------

(setq-default image-dired-dir "/tmp/image-dired") ; where to store thumbnails
(setq-default image-dired-thumb-width 100)
(setq-default image-dired-thumb-height 100)

(defun my-advise-image-dired (&optional args)
  (when (eq major-mode 'dired-mode)
    (dired-hide-details-mode)
    (when (= 1 (count-windows))
      (split-window-right))
    (evil-window-set-width 25)))

(advice-add 'image-dired-display-thumbs :before 'my-advise-image-dired)

(with-eval-after-load "image-dired"
  ;; show full size
  (define-key image-dired-thumbnail-mode-map (kbd "M-<return>")
    (lambda ()
      (interactive)
      (let ((current-prefix-arg 4)) ;; emulate C-u
	(call-interactively 'image-dired-display-thumbnail-original-image)))))

;;; stop opening multiple image buffers
(push '((lambda (buf actions)
	  (eq 'image-mode (with-current-buffer buf major-mode)))
        (display-buffer-reuse-window display-buffer-reuse-mode-window display-buffer-use-some-window))
      display-buffer-alist)

;; put the thumbnail buffer at the bottom
(push '((lambda (buf actions)
	  (eq 'image-dired-thumbnail-mode (with-current-buffer buf major-mode)))
        (display-buffer-reuse-window display-buffer-at-bottom)
        (window-height . 6))
      display-buffer-alist)

;; ----------------------------------------------------------------------------
;;| Magit
;; ----------------------------------------------------------------------------

(defun my-magit-hook ()
  (evil-local-mode 1))

(defun my-magit-repolist-hook ()
  (evil-local-mode 1)
  (beginning-of-buffer))

(defun my-magit-list-repos ()
  (interactive)
  (other-window 1)
  (setq magit-repository-directories '())
  (dolist (proj (my-list-repos))
    (let ((dir (cdr proj)))
      (push `(,dir . 0) magit-repository-directories)))
  (magit-list-repositories))

(defun my-git-commit-mode-hook ()
  ;; want completion on elisp symbols
  (modify-syntax-entry ?- "_"))

(add-hook 'git-commit-mode-hook 'my-git-commit-mode-hook)

(with-eval-after-load 'magit

  (evil-collection-magit-setup)

  (add-hook 'magit-mode-hook #'my-magit-hook)

  (setq magit-delete-by-moving-to-trash nil)

  (evil-define-key 'normal magit-mode-map (kbd "<escape>") nil) ;; stop escape burying buffer
  (evil-define-key 'normal magit-mode-map (kbd "C-j") nil)
  (evil-define-key 'normal magit-mode-map (kbd "C-k") nil)
  (evil-define-key 'normal magit-mode-map (kbd "p") 'magit-section-backward)
  (evil-define-key 'normal magit-mode-map (kbd "n") 'magit-section-forward))

(with-eval-after-load 'magit-repos

  (add-hook 'magit-repolist-mode-hook #'my-magit-repolist-hook)

  (evil-define-key 'normal magit-repolist-mode-map (kbd "RET") 'magit-repolist-status)

  (setq magit-repolist-sort-key '("B>U" . t))
  (setq magit-repolist-column-flag-alist '((magit-unstaged-files . "U")
					   (magit-staged-files . "S"))
	magit-repolist-columns '(("Branch" 20 magit-repolist-column-branch nil)
				 ("Flag" 4 magit-repolist-column-flag)
				 ("Path" 50 magit-repolist-column-path nil)
				 ;; ("Name" 25 magit-repolist-column-ident nil)
				 ("B<U" 3 magit-repolist-column-unpulled-from-upstream
				  ((:right-align t)
				   (:help-echo "Upstream changes not in branch")))
				 ("B>U" 3 magit-repolist-column-unpushed-to-upstream
				  ((:right-align t)
				   (:help-echo "Local changes not in upstream"))))))

(require 'magit)

(evil-leader/set-key "v" 'magit-status)
(global-set-key (kbd "C-c m") 'magit-status)
(global-set-key (kbd "C-c M") #'my-magit-list-repos)

;; ----------------------------------------------------------------------------
;;| Ediff
;; ----------------------------------------------------------------------------

(setq-default ediff-custom-diff-options "-u")

(defun my-diff-mode-hook ()
  ;; stop overriding new window switch key
  (define-key diff-mode-map (kbd "M-o") nil))

(add-hook 'diff-mode-hook #'my-diff-mode-hook)

;; ----------------------------------------------------------------------------
;;| Compilation
;; ----------------------------------------------------------------------------

(defun my-compilation-mode-hook ()
  (modify-syntax-entry ?_ "w") ;; _ is word constituent, so * and # works
  (visual-line-mode)
  (evil-local-mode)
  (evil-local-set-key 'normal (kbd "q") 'quit-window)
  (evil-emacs-state))

(defun my-grep-mode-hook ()
  (evil-local-mode -1))

(add-hook 'compilation-mode-hook 'my-compilation-mode-hook)
(add-hook 'grep-mode-hook 'my-grep-mode-hook)

(defun my-compilation-filter-hook ()
 (ansi-color-apply-on-region compilation-filter-start (point)))

(add-hook 'compilation-filter-hook 'my-compilation-filter-hook)

(global-set-key (kbd "C-c C-SPC") #'project-compile)
(global-set-key (kbd "C-c C-,") #'recompile)
(global-set-key (kbd "C-c ,") #'recompile)
(global-set-key (kbd "C-c g") (lambda () (interactive) (my-jump-buffer "*compilation*")))
(define-key compilation-mode-map (kbd "SPC") evil-leader--default-map)
(define-key compilation-mode-map (kbd "C-w") 'evil-window-map)
(define-key compilation-mode-map (kbd "g") nil)

;; ----------------------------------------------------------------------------
;;| Makefile
;; ----------------------------------------------------------------------------

(add-hook 'makefile-mode-hook 'my-syntax-entry)

(defun my-makefile-no-warn-suspicious-lines ())
(advice-add 'makefile-warn-suspicious-lines :override #'my-makefile-no-warn-suspicious-lines)

(with-eval-after-load "cmake-mode"
  (add-hook 'cmake-mode-hook 'my-syntax-entry))

(defun my-log-settings ()
  (my-syntax-entry)
  (toggle-truncate-lines 0))

(add-to-list 'auto-mode-alist '("\\.log\\'" . my-log-settings))

;; ----------------------------------------------------------------------------
;;| Yaml
;; ----------------------------------------------------------------------------

(defun my-yaml-hook ()
  (auto-fill-mode -1)
  (setq-local evil-shift-width 2)
  ;; = is punctuation
  (modify-syntax-entry ?= "."))

(add-hook 'yaml-mode-hook 'my-yaml-hook)

;; ----------------------------------------------------------------------------
;;| Comint
;; ----------------------------------------------------------------------------

(setq comint-prompt-read-only t)

(with-eval-after-load 'comint
  (define-key comint-mode-map (kbd "C-c C-l") (lambda ()
						(interactive)
						(if vertico-mode
						    (consult-history)
						  (comint-dynamic-list-input-ring))))
  (define-key comint-mode-map (kbd "M-r") 'move-to-window-line-top-bottom)
  (define-key comint-mode-map (kbd "C-r") 'comint-history-isearch-backward)

  ;; When the cursor is in the middle of the shell output, stop the
  ;; return key from pasting the whole lot back and executing it
  (define-key comint-mode-map
    (kbd (if (display-graphic-p) "<return>" "RET"))
    (lambda ()
      (interactive)
      (if (comint-after-pmark-p)
	  (comint-send-input)
	(message "Point is before process mark, NOT sending")))))

;; ----------------------------------------------------------------------------
;;| Shell
;; ----------------------------------------------------------------------------

(with-eval-after-load 'shell
  (define-key shell-mode-map (kbd "M-_") 'comint-insert-previous-argument)
  (define-key shell-mode-map (kbd "SPC") 'comint-magic-space)
  (define-key shell-mode-map (kbd "C-d") 'my-shell-ctrl-d))

(defun my-project-buffer-name (mode)
  (concat "*" (downcase mode)
          ":" (file-name-nondirectory
               (directory-file-name default-directory))
          "*"))

(advice-add 'project-prefixed-buffer-name :override 'my-project-buffer-name)

(defun my-shell ()
  (interactive)
  (if (and (not (eq major-mode 'dired-mode))
	   (project-current nil))
      (project-shell)
    (call-interactively 'shell)))

(defun my-split-shell ()
  (interactive)
  (let ((evil-split-window-below t))
    (evil-window-split))
  (my-shell))

(defun my-jump-to-shell ()
  (interactive)
  (let ((target (or (first (match-buffers "^\\*gud-.*\\*$"))
		    (get-buffer "*compilation*<2>")
		    (get-buffer "*Async Shell Command*")
		    (first (match-buffers "^\\*shell.*\\*$")))))
    (if target
	(let ((w (get-buffer-window target)))
          (if w
              (select-window w)
            (switch-to-buffer target)))
      (message "No shell to jump to"))))

(defun my-shell-ctrl-d ()
  "first C-d ends the shell, second C-d deletes the buffer and
  closes the window"
  (interactive)
  (if (get-buffer-process (current-buffer))
      (progn
	;; Fix "shell-apply-ansi-color: Text is read-only" error
	(advice-add 'comint-send-eof :override #'process-send-eof)
	(unwind-protect
	    (comint-delchar-or-maybe-eof 1)
	  (advice-remove 'comint-send-eof #'process-send-eof)))
    (kill-buffer)
    (if (> (count-windows) 2)
	(delete-window))))

(defun my-shell-hook ()
  (undo-tree-mode -1)			; don't shadow M-_
  (fancy-dabbrev-mode -1)
  (visual-line-mode 0)
  (toggle-truncate-lines 0)

  ;; fill out longest common part of filename first
  (setq-local completion-styles '(emacs21 flex))

  ;; don't ignore .git, etc
  (setq-local completion-ignored-extensions nil
	      completion-ignore-case nil))

(add-hook 'shell-mode-hook 'my-shell-hook)

(add-hook 'sh-mode-hook 'my-syntax-entry)

(global-set-key (kbd "C-c z") 'my-shell)
(global-set-key (kbd "C-c v") 'my-split-shell)
(global-set-key (kbd "C-c h") 'my-jump-to-shell)

;; ----------------------------------------------------------------------------
;;| Term
;; ----------------------------------------------------------------------------

(defun my-expose-global-binding (map binding)
  (define-key map binding (lookup-key (current-global-map) binding)))

(with-eval-after-load 'term
  (my-expose-global-binding term-raw-map (kbd "M-o"))
  (my-expose-global-binding term-raw-map (kbd "C-j")))

(require 'terminal-here)

(global-set-key (kbd "C-c t") #'terminal-here-launch)

;; ----------------------------------------------------------------------------
;;| Eshell
;; ----------------------------------------------------------------------------

;; (defun my-eshell-last-arg ()
;;   "Insert last argument of previous command"
;;   (interactive)
;;   (insert (car (last (split-string-shell-command (eshell-previous-input-string 0))))))

;; (defun my-eshell-ctrl-d ()
;;   "If the input line is blank, close the shell, otherwise delete-char"
;;   (interactive)
;;   (if (not (string= "" (eshell-get-old-input)))
;;       (call-interactively 'delete-char)
;;     (kill-buffer)
;;     (if (> (count-windows) 2)
;; 	(delete-window))))

;; (defun my-eshell-hook ()
;;   (undo-tree-mode -1)			; don't shadow M-_
;;   (fancy-dabbrev-mode -1)
;;   (visual-line-mode 0)
;;   (toggle-truncate-lines 1)
;;   (define-key eshell-hist-mode-map (kbd "M-r") #'move-to-window-line-top-bottom)
;;   (define-key eshell-hist-mode-map (kbd "C-r") #'helm-eshell-history)
;;   (define-key eshell-hist-mode-map (kbd "C-c C-l") #'eshell/clear)
;;   (define-key eshell-mode-map (kbd "M-m") 'eshell-bol)
;;   (local-set-key (kbd "M-_") 'my-eshell-last-arg)
;;   (local-set-key (kbd "C-d") 'my-eshell-ctrl-d))

;; (add-hook 'eshell-mode-hook 'my-eshell-hook)

;; (defun my-split-eshell ()
;;   (interactive)
;;   (let ((evil-split-window-below t))
;;     (evil-window-split))
;;   (eshell))

;; (global-set-key (kbd "C-c M-e") 'my-split-eshell)

;; ----------------------------------------------------------------------------
;;| Tags
;; ----------------------------------------------------------------------------

(evil-set-initial-state 'xref--xref-buffer-mode 'emacs)

(defun my-dir-predicate (subdir)
  (let* ((name (file-name-nondirectory
		(directory-file-name subdir))))
    (not (or (string= name "build")
	     (string= name ".git")))))

(defun my-rebuild-and-load-tags (&optional one-project)
  "Find a TAGS file above the default-directory, invoke make TAGS
in that directory. If run with a prefix arg, generate tags in the
current project instead. Visit the tags file."
  (interactive "P")
  (if one-project
      (let ((proj (my-find-project-root))
	    (ctags (if (eq system-type 'darwin) "uctags" "ctags")))
	(when (y-or-n-p (format "Run %s in %s?" ctags proj))
	  (message (format "Running %s in %s" ctags proj))
	  (when (= 0 (shell-command
		      (format "cd \"%s\" && %s -R -e -f TAGS --exclude=.git --exclude=build . > /dev/null"
			      proj ctags)))
	    (visit-tags-table (concat proj "TAGS")))))

    (let* ((dir (locate-dominating-file default-directory "TAGS"))
	   (path (and dir (expand-file-name (file-name-as-directory dir)))))
      (if (not path)
	  (message (format "No existing TAGS file found above %s" default-directory))
	(when (y-or-n-p (format "Run 'make TAGS' in %s" path))
	  (message (format "Running 'make -C %s TAGS'" path))
	  (call-process "make" nil nil nil "-C" path "TAGS")
	  ;; (visit-tags-table (concat path "TAGS"))
	  )))))

(defun my-find-tags-files ()
  "Find TAGS files and set tags-table-list"
  (let ((all '()))
    (message "Searching for TAGS files...")
    (dolist (dir (if (eq system-type 'darwin)
		     '("~/dev/")
		   '("~/dev/git")))
      (setq all (nconc all (directory-files-recursively
			    (expand-file-name dir) "^TAGS$" nil
			    'my-dir-predicate))))
    (setq-default tags-table-list all)))

(global-set-key (kbd "C-c M-.") #'my-rebuild-and-load-tags)
(evil-global-set-key 'motion (kbd "C-w .")   #'xref-find-definitions-other-window)
(evil-global-set-key 'motion (kbd "C-w C-.") #'xref-find-definitions-other-window)

(setq xref-show-definitions-function #'xref-show-definitions-completing-read)

;; ----------------------------------------------------------------------------
;;| Lisp
;; ----------------------------------------------------------------------------

(require 'paredit)
(autoload 'enable-paredit-mode "paredit" "Turn on pseudo-structural editing of Lisp code." t)

(defun my-lisp-ctrl-j (&optional prefix)
  (interactive "P")
  (if prefix
      ;; still works if cursor is on a blank line below
      (pp-eval-last-sexp t)
    (call-interactively (lookup-key (current-global-map) (kbd "C-j")))))

(define-key paredit-mode-map (kbd "C-j") #'my-lisp-ctrl-j)
(define-key paredit-mode-map (kbd "M-s") nil)
(define-key paredit-mode-map (kbd "M-s s") 'paredit-splice-sexp)
(define-key paredit-mode-map (kbd "M-s r") 'paredit-raise-sexp)
(define-key paredit-mode-map (kbd "M-r") nil)

(defun my-lisp-common-hook ()
  (enable-paredit-mode)
  (evil-local-mode 1)
  (setq-local evil-symbol-word-search t))

(add-hook 'emacs-lisp-mode-hook       'my-lisp-common-hook 'append)
(add-hook 'lisp-mode-hook             'my-lisp-common-hook 'append)
(add-hook 'lisp-interaction-mode-hook 'my-lisp-common-hook 'append)
(add-hook 'scheme-mode-hook           'my-lisp-common-hook 'append)

(advice-add 'paredit-comment-dwim :after 'my-advise-comment)

(defun my-reindent-lisp-defun ()
  (interactive)
  (save-excursion
    (evil-previous-open-paren 20)
    (indent-sexp)))
(define-key lisp-mode-shared-map (kbd "C-c C-q") 'my-reindent-lisp-defun)

;; ----------------------------------------------------------------------------
;;| Python
;; ----------------------------------------------------------------------------

(defvar my-python-interp "python3")
(setq-default python-shell-interpreter my-python-interp)

(defun my-python-shell-mode-hook ()
  (toggle-truncate-lines 0)
  (fancy-dabbrev-mode -1))

(defun my-python-mode-hook ()
  (my-syntax-entry)
  (setq-local tab-width 4)
  (setq-local evil-shift-width 4))

(add-hook 'python-mode-hook 'my-python-mode-hook)
(add-hook 'inferior-python-mode-hook 'my-python-shell-mode-hook)

;; (with-eval-after-load 'python
;;   (define-key python-mode-map (kbd "C-c C-a") 'pyvenv-activate))

(defun my-python-send-region ()
  (interactive)
  (if (use-region-p)
      (call-interactively 'python-shell-send-region)
    (message "No region active")))

(evil-leader/set-key-for-mode 'python-mode "." 'my-python-send-region)

(evil-set-initial-state 'inferior-python-mode 'emacs)

(add-to-list 'auto-mode-alist '("/SConstruct\\'" . python-mode))
(add-to-list 'auto-mode-alist '("/SConscript\\'" . python-mode))

;; ----------------------------------------------------------------------------
;;| Eglot
;; ----------------------------------------------------------------------------

;; (require 'eglot)

;; (add-to-list 'eglot-server-programs '(python-mode . ("pylsp" "-v")))

;; (setq eglot-autoshutdown t)

;; ----------------------------------------------------------------------------
;;| Cpp
;; ----------------------------------------------------------------------------

(defun my-wrap-if-endif (x &optional else)
  "Wrap the paragraph or region in #if x #endif,
    or #if x #else #endif if else is non-nil"
  (let (;; (is-blank-line (lambda ()
	;;               (not (string-match-p "." (thing-at-point 'line)))))
	(the-indent)
	(endpos)
	(prefix (lambda (c)
		  (newline)
		  (forward-line -1)
		  (indent-to c)
		  (insert (concat "#if " (number-to-string x)))
		  (when else
		    (insert "\n")
		    (indent-to c)
		    (setq endpos (point))
		    (insert "#else")))))

    (if (use-region-p)
	(let ((b (min (region-beginning) (region-end)))
	      (e (max (region-beginning) (region-end))))
	  (save-excursion
	    (goto-char b)
	    (setq the-indent (current-indentation)))
	  (save-excursion               ;; suffix
	    (goto-char e)
	    (newline)
	    (forward-line -1)
	    (indent-to the-indent)
	    (insert "#endif"))
	  (save-excursion               ;; prefix
	    (goto-char b)
	    (funcall prefix the-indent)))

      ;; no region, use paragraph
      (save-excursion                   ;; prefix
	(backward-paragraph)
	(forward-line)
	(setq the-indent (current-indentation))
	(funcall prefix the-indent))
      (save-excursion                   ;; suffix
	(forward-paragraph)
	(indent-to the-indent)
	(move-end-of-line 1)
	(insert "#endif\n")))

    (when endpos
      (goto-char endpos)
      (evil-open-above 1)
      (indent-to the-indent))))

(defun my-jump-to-header (&optional open-in-other-window)
  "Jump between C/C++ source file and corresponding header"
  (interactive "P")
  (let ((fn (buffer-file-name)))
    (if (not fn)
	(message "Buffer has no filename")
      (let* ((ext (file-name-extension fn))
	     (regex (concat "^" (file-name-base fn) "\\." (if (string= ext "h") "c" "h")))
	     (dir (my-find-project-root))
	     (files (directory-files-recursively dir regex nil 'my-dir-predicate))
	     (len (length files)))
	(if (= 0 len)
	    (message (format "No files found under \"%s\" matching \"%s\"" dir regex))
	  (let ((func (lambda ()
			(find-file (if (= 1 len)
				       (car files)
				     (completing-read "File: " files nil t))))))
	    (if open-in-other-window
		(let* ((switch-to-buffer-obey-display-actions t)
		       (display-buffer-overriding-action '((display-buffer-pop-up-window)
							   (inhibit-same-window . t))))
		  (funcall func))
	      (funcall func))
	    (message (buffer-file-name))))))))

;; https://www.gnu.org/software/emacs/manual/html_node/efaq/Customizing-C-and-C_002b_002b-indentation.html
(c-add-style "my-c-style"
	     '("linux"
	       (c-offsets-alist
		;; when a closing bracket is on it's own line don't
		;; indent more
		(arglist-close . 0)
		;; stop indenting function inside namespace
		(innamespace . 0)
		(topmost-intro . 0))))

(setq c-default-style "my-c-style")
(setq c-tab-always-indent nil)

(defvar my-cc-path)

(defun my-cc-settings (path)
  (modify-syntax-entry ?_ "w")
  (evil-local-set-key 'normal (kbd "[#") 'c-up-conditional)
  (auto-fill-mode -1)

  (hide-ifdef-mode 1)
  (add-hook 'after-save-hook 'hide-ifdefs 'append 'local)

  (make-local-variable path)
  (when (bound-and-true-p my-cc-path)
    (dolist (x my-cc-path)
      (add-to-list path x)))
  (vc-refresh-state)
  (add-to-list path (my-find-project-root))

  (when (not tags-table-list)
    (my-find-tags-files)))

(with-eval-after-load "hideif"
  ;; don't hide #ifdef FOO ... #endif, where FOO is undefined
  (setq hif-undefined-symbol t))

(require 'ffap)

(defun my-cpp-mode-hook ()
  (my-cc-settings 'ffap-c++-path))

(defun my-c-mode-hook ()
  (my-cc-settings 'ffap-c-path))

(add-hook 'c++-mode-hook 'my-cpp-mode-hook t)
(add-hook 'c-mode-hook 'my-c-mode-hook t)

(dolist (mode '(c++-mode c-mode))
  (evil-leader/set-key-for-mode mode
    "0" (lambda () (interactive) (my-wrap-if-endif 0))
    "3" (lambda () (interactive) (my-wrap-if-endif 1))
    "2" (lambda () (interactive) (my-wrap-if-endif 1 t))))

;; 4 character tabs or spaces for some projects
(dir-locals-set-class-variables 'fourchartabs
				'((c-mode . ((tab-width . 4)
					     (evil-shift-width . 4)))
				  (c++-mode . ((tab-width . 4)
					       (evil-shift-width . 4)))))
(dir-locals-set-class-variables 'fourspaces
				'((c-mode . ((tab-width . 4)
					     (evil-shift-width . 4)
					     (indent-tabs-mode . nil)))
				  (c++-mode . ((tab-width . 4)
					       (evil-shift-width . 4)
					       (indent-tabs-mode . nil)))))

(define-skeleton my-cpp-include "" nil
  "#include \"" - "\"")

(define-skeleton my-cpp-include-sys "" nil
  "#include <" - ">")

(define-skeleton my-cpp-for "" nil
  > "for ("
  (skeleton-read "Type: " "int") " "
  (setq v1 (skeleton-read "Variable: " "")) "=0; "
  v1 "<"
  (skeleton-read "End: " "") "; ++" v1 ") {\n"
  > - "\n"
  > -1 "}\n")

(define-skeleton my-cpp-for-iter "" nil
  > "for (\t"
  (skeleton-read "Container Type: " "std::vector<int>") "::"
  (skeleton-read "Iterator: " "const_iterator") "\n"
  > -1 (setq v1 (skeleton-read "Variable: " "it")) "="
  (setq v2 (skeleton-read "Container: " "")) ".begin(); " v1 "!=" v2 ".end(); ++" v1 "\n"
  > -2 ") {\n"
  > - "\n"
  > -1 "}\n")

(define-skeleton my-cpp-print-vec "" "Variable: "
  "<< " str "[0] << \" \" <<\n"
  > str "[1] << \" \" <<\n"
  > str "[2] << \" \" <<" -)

(define-skeleton my-cpp-include-guard "" nil
  "#ifndef INCLUDED_"
  (upcase (setq v1 (skeleton-read "Namespace: ")))
  "_"
  (setq v2 (upcase
	    (let ((name (buffer-file-name)))
	      (if name
		  (file-name-nondirectory
		   (file-name-sans-extension name))
		(skeleton-read "Name: "))))) "_H\n"
  "#define INCLUDED_" (upcase v1) "_" v2 "_H\n\n"
  "namespace " v1 " {\n\n"
  -
  "\n\n} // end namespace\n\n"
  "#endif\n")

(define-skeleton my-cpp-main "" nil
  "#include <iostream>\n\n"
  "using std::cerr;\n\n"
  "int main(int argc, const char *argv[]) {\n"
  > - "\n"
  > "return 0;\n}\n")

(with-eval-after-load "cc-mode"
  (define-key c-mode-base-map (kbd "C-c C-b") nil) ; don't want c-submit-bug-report
  (define-key c-mode-base-map (kbd "C-c C-i") #'my-jump-to-header)

  (dolist (table (list c-mode-abbrev-table c++-mode-abbrev-table))
    (define-abbrev table "inn"  "" 'my-cpp-include)
    (define-abbrev table "inc"  "" 'my-cpp-include-sys)
    (define-abbrev table "fo"   "" 'my-cpp-for)
    (define-abbrev table "fori" "" 'my-cpp-for-iter)
    (define-abbrev table "pv"   "" 'my-cpp-print-vec)
    (define-abbrev table "main" "" 'my-cpp-main)))

(auto-insert-mode 1)
(define-auto-insert "\\.h\\'" 'my-cpp-include-guard)

;; ----------------------------------------------------------------------------
;;| Maya, Houdini, Arnold
;; ----------------------------------------------------------------------------

;; maya mel
(when (file-directory-p "~/dev/ermine/emacs")
  (add-to-list 'load-path "~/dev/ermine/emacs")
  (require 'ermine))

;; houdini vex
(add-to-list 'auto-mode-alist '("\\.vex\\'" . c-mode))

;;; arnold
(defun my-arnold-settings ()
  (set (make-local-variable 'comment-start) "#"))
(add-to-list 'auto-mode-alist '("\\.ass\\'" . my-arnold-settings))

;; ----------------------------------------------------------------------------
;;| Debug, gdb
;; ----------------------------------------------------------------------------

(defun my-gdb-mode-hook ()
  (define-key gud-mode-map (kbd "C-c C-r") 'comint-show-output)
  (define-key gud-mode-map (kbd "C-c C-p") 'comint-previous-prompt)
  (define-key gud-mode-map (kbd "C-c C-n") 'comint-next-prompt)
  (define-key gud-mode-map (kbd "C-r") 'comint-history-isearch-backward)
  (define-key gud-mode-map (kbd "C-c C-j") 'gud-down)
  (define-key gud-mode-map (kbd "C-c C-k") 'gud-up)
  (define-key gud-mode-map (kbd "C-c C-u") 'comint-kill-input))

(add-hook 'gdb-mode-hook 'my-gdb-mode-hook)

(setq gdb-many-windows nil)

;; TODO override gdb-setup-windows instead

;;; https://stackoverflow.com/a/41326527
(defun my-set-gdb-layout(&optional c-buffer)

  (if (not c-buffer)
      (setq c-buffer (window-buffer (selected-window)))) ;; save current buffer

  (switch-to-buffer gud-comint-buffer)
  (delete-other-windows)

  (let* ((w-source (selected-window))						     ;; left top
	 (w-gdb (split-window w-source nil 'right))				     ;; right bottom
	 (w-locals (split-window w-gdb nil 'above))				     ;; right middle bottom
	 (w-stack (split-window w-locals nil 'above))				     ;; right middle top
	 ;; (w-breakpoints (split-window w-stack nil 'above))			     ;; right top
	 (w-io (split-window w-source (floor (* 0.5 (window-body-height))) 'below))  ;; left bottom
	 )

    (set-window-buffer w-io (or (first (match-buffers "^\\*input/output of .*\\*$"))
				(get-buffer "*compilation*")
				(get-buffer "")
				(gdb-get-buffer-create 'gdb-inferior-io)))
    ;; (set-window-buffer w-breakpoints (gdb-get-buffer-create 'gdb-breakpoints-buffer))
    (set-window-buffer w-locals (gdb-get-buffer-create 'gdb-locals-buffer))
    (set-window-buffer w-stack (gdb-get-buffer-create 'gdb-stack-buffer))
    (set-window-buffer w-gdb gud-comint-buffer)

    (set-window-dedicated-p w-io t)
    ;; (set-window-dedicated-p w-breakpoints t)
    (set-window-dedicated-p w-locals t)
    (set-window-dedicated-p w-stack t)
    (set-window-dedicated-p w-gdb t)
    (set-window-dedicated-p w-source nil)

    (select-window w-source)
    (set-window-buffer w-source c-buffer)))

(defadvice gdb (around args activate)
  (setq global-config-editing (current-window-configuration)) ;; to restore: (set-window-configuration c-editing)
  (let ((c-buffer (window-buffer (selected-window))) ;; save current buffer
        )
    ad-do-it
    (my-set-gdb-layout c-buffer)))
(defadvice gdb-reset (around args activate)
  ad-do-it
  (set-window-configuration global-config-editing))

;; ----------------------------------------------------------------------------
;;| Font
;; ----------------------------------------------------------------------------

(defun my-font-config ()
  (interactive)

  (when (display-graphic-p)

    ;; linux: install to ~/.fonts/  then fc-cache -v ~/.fonts
    (when (eq system-type 'gnu/linux)

      (set-face-attribute 'default nil :font "Menlo:pixelsize=14:weight=normal:slant=normal:width=normal:spacing=100:scalable=true")

      (if (string= (string-trim (shell-command-to-string
				 "xrandr | awk '/^HDMI-1/{print $2}'"))
		   "connected")
	  ;; external monitor
	  (set-face-attribute 'default nil :height 105)
	;; laptop screen
	(set-face-attribute 'default nil :height 115)))

    (when (eq system-type 'darwin)
      (set-face-attribute 'default nil :family "Menlo" :height 160))))

;; ----------------------------------------------------------------------------
;;| Colour theme
;; ----------------------------------------------------------------------------

(require 'font-lock)
(global-font-lock-mode t)
(setq font-lock-maximum-decoration t)

(defun my-set-dark-mode (val)
  (when (eq system-type 'darwin)
    (shell-command (format "osascript -e 'tell app \"System Events\" to tell appearance preferences to set dark mode to %s'" (if val "true" "false")))))

(defun my-theme-dark (x)
  (mapcar #'disable-theme custom-enabled-themes)
  (cond
   ((= x 0)
    (require 'reykjavik-theme)
    (load-theme 'reykjavik)
    (load-theme 'my-override-dark))
   ((= x 1)
    (require 'nordic-night-theme)
    (load-theme 'nordic-night)
    (load-theme 'my-override-dark3))
   ((= x 2)
    (require 'nord-theme)
    (load-theme 'nord)
    (load-theme 'my-override-dark2))
   ((= x 3)
    (load-theme 'ef-winter)
    (load-theme 'my-override-dark2)))

  (set-cursor-color "white")
  (setq evil-normal-state-cursor '(box "white"))
  (setq evil-insert-state-cursor '(box "orange"))

  (my-set-dark-mode t))

(defun my-theme-light (x)
  (mapcar #'disable-theme custom-enabled-themes)
  (cond
   ((= x 0)
    (require 'soft-morning-theme)
    (load-theme 'soft-morning)
    (load-theme 'my-override-light))
   ((= x 1)
    (require 'sandcastle-theme)
    (load-theme 'sandcastle)))

  (set-cursor-color "black")
  (setq evil-normal-state-cursor '(box "black"))
  (setq evil-insert-state-cursor '(box "orange"))

  (my-set-dark-mode nil))

(require 'hydra)

(defhydra my-theme-hydra ()
  "Theme"
  ("u" (lambda () (interactive) (my-theme-dark 0)) "reykjavik")
  ("i" (lambda () (interactive) (my-theme-dark 1)) "nordic-night")
  ("o" (lambda () (interactive) (my-theme-dark 2)) "nord")
  ("p" (lambda () (interactive) (my-theme-dark 3)) "ef-winter")
  ("f" (lambda () (interactive) (my-theme-light 0)) "soft-morning")
  ("d" (lambda () (interactive) (my-theme-light 1)) "sandcastle"))

(define-key evil-window-map (kbd "SPC") 'my-theme-hydra/body)

;; ----------------------------------------------------------------------------
;;| Splash screen
;; ----------------------------------------------------------------------------

(defun my-window-setup-hook ()
  (when (and (display-graphic-p)
	     (file-exists-p "~/Pictures/splash"))
    (require 'seq)
    (setq fancy-splash-image
	  (let ((choices (seq-filter
			  (lambda (fn)
			    (let ((ext (file-name-extension fn)))
			      (or (string= ext "jpg")
				  (string= ext "jpeg")
				  (string= ext "png"))))
			  (directory-files "~/Pictures/splash"
					   t "^\\([^.]\\|\\.[^.]\\|\\.\\..\\)"))))
	    (elt choices (random (length choices))))))

  (unless (display-graphic-p)
    ;; see terminal background colour/image
    (set-face-background 'default "unspecified-bg" (selected-frame)))

  (if (< (decoded-time-hour (decode-time)) 13)
      (my-theme-light 0)
    (my-theme-dark 0))

  (my-font-config))

(add-hook 'window-setup-hook 'my-window-setup-hook)

;; splash screen disappears sometimes
(defun my-override-use-splash-screens (&rest args)
  (display-graphic-p))
(advice-add 'use-fancy-splash-screens-p :override 'my-override-use-splash-screens)

(with-eval-after-load "evil-leader"
  (define-key splash-screen-keymap (kbd "SPC") evil-leader--default-map))

;; ----------------------------------------------------------------------------
;;| Music
;; ----------------------------------------------------------------------------

(defun my-add-dired-to-bongo ()
  (interactive)
  (dolist (fn (dired-get-marked-files))
    (bongo-insert-file fn)))

(when (or (eq system-type 'darwin)
	  (and (eq system-type 'gnu/linux)
	       (display-graphic-p)
	       (string= (string-trim (shell-command-to-string "lsb_release -i -s")) "Ubuntu")))

  (require 'bongo) ;; need this before opening a playlist

  (evil-leader/set-key "b" #'bongo)
  (define-key dired-mode-map (kbd "b") 'my-add-dired-to-bongo)

  (setq bongo-logo nil)
  (setq bongo-display-track-icons nil)
  ;; seek doesn't work reliably with vlc backend
  ;; need at least mplayer 1.5 on macOS 11 to fix echoing
  ;;	brew install mplayer
  ;; mplayer volume resets to max after seeking
  (setq bongo-enabled-backends '(vlc))
  (setq bongo-vlc-program-name (if (eq system-type 'darwin)
				   "/Applications/VLC.app/Contents/MacOS/VLC"
				 "/usr/bin/vlc"))

  (defun my-bongo-mode-hook ()
    (define-key bongo-mode-map (kbd "SPC") evil-leader--default-map)
    (define-key bongo-mode-map (kbd "z") (kbd "C-c C-p"))
    (define-key bongo-mode-map (kbd "x") 'bongo-start/stop)
    (define-key bongo-mode-map (kbd "c") 'bongo-pause/resume)
    (global-set-key (kbd "<f7>") 'bongo-play-previous)
    (global-set-key (kbd "<f8>") 'bongo-pause/resume)
    (global-set-key (kbd "<f9>") 'bongo-play-next)
    (define-key bongo-mode-map (kbd "b") (kbd "C-c C-n"))
    (define-key bongo-mode-map (kbd "f") nil)
    (define-key bongo-mode-map (kbd "j") (kbd "n"))
    (define-key bongo-mode-map (kbd "k") (kbd "p"))
    (define-key bongo-mode-map (kbd "o") 'bongo-switch-buffers)
    (define-key bongo-mode-map (kbd "O") 'bongo-list-buffers)
    (define-key bongo-mode-map (kbd "V") 'bongo-seek-backward-60)
    (define-key bongo-mode-map (kbd "h") 'bongo-seek-backward-10)
    (define-key bongo-mode-map (kbd "H") 'bongo-seek-backward-3)
    (define-key bongo-mode-map (kbd "L") 'bongo-seek-forward-3)
    (define-key bongo-mode-map (kbd "l") 'bongo-seek-forward-10)
    (define-key bongo-mode-map (kbd "v") 'bongo-seek-forward-60)
    (define-key bongo-mode-map (kbd ";") 'bongo-recenter)

    (bongo-mode-line-indicator-mode -1))

  (defun my-bongo-set-volume ()
    (let ((process (get-process "bongo-mplayer")))
      (when process
	(process-send-string process "volume 5 1\n")))
    (let ((process (get-process "bongo-vlc")))
      (when process
	(process-send-string process "volume 175\n"))))

  (defun my-bongo-start-hook ()
    (when (get-process "bongo-vlc")
      (sit-for 0.2))
    (my-bongo-set-volume))

  ;; stop asking for confirmation to stop player before killing buffer
  (defun my-bongo-confirm-player-stop ()
    (or (not bongo-player)
	(bongo-player-stop bongo-player)
	t))
  (advice-add 'bongo-confirm-player-stop :override 'my-bongo-confirm-player-stop)

  (add-hook 'bongo-player-started-hook 'my-bongo-start-hook)
  (add-hook 'bongo-mode-hook 'my-bongo-mode-hook))

;; ----------------------------------------------------------------------------
;;| Customs
;; ----------------------------------------------------------------------------

(load "~/dotfiles/init.el" t)

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(compilation-ask-about-save nil)
 '(compilation-scroll-output t)
 '(compilation-skip-threshold 2)
 '(compile-command "make ")
 '(custom-safe-themes
   '("e17d91a99e14fc72f71f531f07d3dff44238c69f599998b50e95e67b589d8fa1" "a6e8bcffe4d8cac7463c5a7c67c0908316cc616da3816d3ce35c325d5e02fd97" "1ef170921412215be45e6818ef312734130a222b54e3a24cb20e7fa4f461754a" "d541f776fef47075c15613b88c8e41a275df254de643ba39ac19ac9fefc1d3bd" "46f5e010e0118cc5aaea1749cc6a15be4dfce27c0a195a0dff40684e2381cf87" "e6bd62f1ff1b0f1bffe43b0eebd7b0da2f3ab36c155ece6246e248e309ce2d36" "f366d4bc6d14dcac2963d45df51956b2409a15b770ec2f6d730e73ce0ca5c8a7" "7b8f5bbdc7c316ee62f271acf6bcd0e0b8a272fdffe908f8c920b0ba34871d98" "046a2b81d13afddae309930ef85d458c4f5d278a69448e5a5261a5c78598e012" "a5270d86fac30303c5910be7403467662d7601b821af2ff0c4eb181153ebfc0a" "00445e6f15d31e9afaa23ed0d765850e9cd5e929be5e8e63b114a3346236c44c" "4c56af497ddf0e30f65a7232a8ee21b3d62a8c332c6b268c81e9ea99b11da0d3" "57a29645c35ae5ce1660d5987d3da5869b048477a7801ce7ab57bfb25ce12d3e" "833ddce3314a4e28411edf3c6efde468f6f2616fc31e17a62587d6a9255f4633" "efcecf09905ff85a7c80025551c657299a4d18c5fcfedd3b2f2b6287e4edd659" "5111a41453244802afd93eed1a434e612a8afbdf19c52384dffab129258bab6e" "08e9ac555b44325be211da0b0a16dc2de9c2405d0f963c3c740802ebf48a4a15" "413ba24c4f8a0d187a43d69dc7cbfd8b1d8782739422ba2368eb5f0893f0642a" "6124d0d4205ae5ab279b35ac6bc6a180fbb5ca594616e1e9a22097024c0a8a99" "b940c68944436ab216d83c13a05808bcacf40ac224c4aba2c209c3cbf2c76427" "9a456f2aac10f18204e8ece27c84950c359f91bb06bda8c711bf4f5095ca8250" "bebec7cd48f56fbca1c878d7f43ece10d5390ab95790883d95ae4c0f6045600a" "41c478598f93d62f46ec0ef9fbf351a02012e8651e2a0786e0f85e6ac598f599" "6c595463d2597d0e5bb00c6ee7864b33e9b02d1a2e0fb4e53e1dd965185c8941" "4ed8604560416e549483bd712f1a3000d04ef821e02cc899d5ec2203521ef0d8" "a8a5fd1c8afea56c5943ead67442a652f1f64c8191c257d76988edb0b1ad5dfa" "72ca2b0770981be70839fc2b738fc81f6268477653a6d89df67f0f94eb64e1e7" "77d70eeeb499432a8d6f3ed3d7f719463a75ce200efbe7f1ea5e45425e85ce74" "0e4dbecba219a11a4471c052f79f5151087548d0aeb7a1015aa4b2224dc79235" "03dfda184c3656f421ca0bb928abb879cab82387983c4688c8356c2710890f5c" "5a00e072436d0617fb82253e78bcc9ff9baba5e9ae337128957c4e8851b4b865" "a78291094b33af491e1c91fde2431dd53b85906798fb35b2f08151f37e1500f1" "eb7686ef59efd2208d76e82beca94a46c6f93851cc1bf8f990e2f9ca6512db25" "6123f527373737d3574587d9da84c4908c6dc83939ca69788affae3c3ecfa998" "0a0ec1a745eb67f216b139819634e2d17e80a850005f1b2cd8bd95f8dee459fd" "33ea268218b70aa106ba51a85fe976bfae9cf6931b18ceaf57159c558bbcd1e6" "cd77a3581c0fa37f4f9f1185e2098066fa61aca99ee0a82185ac6881f3211554" "bbb13492a15c3258f29c21d251da1e62f1abb8bbd492386a673dcfab474186af" "0af4fc8329f73bd771df30015858813385461513e044df730fc805a49f5ece52" "ffef467dfed832df46d4e188049e52aad1d64c16070484fc6b62f158ece95471" "907d726da1effbdf880aa57a09b85427ecbd7d529944defdc8e4e84bfad873d0" "7e068da4ba88162324d9773ec066d93c447c76e9f4ae711ddd0c5d3863489c52" "0f08efc35f1190204ac227e8c866b18400612d2137e2d13dcbf4693953681ff3" "60ada0ff6b91687f1a04cc17ad04119e59a7542644c7c59fc135909499400ab8" "820403725cf74083aa7d2dce51ed480a895a33fc1c4b915a613b10722fcd2785" "dad4dee6a844f751e7c7081591290d11d691e9375585a476c1d23997567519fb" "1faee04c6edf65e4f2786749f3c3b2fc46cae72b3483eb4a871de1c31cf130cc" "63df1d9126e997cd7f6ef5f7dd61312b0f65bcb18974e199e82d0e72b8576612" "d89e15a34261019eec9072575d8a924185c27d3da64899905f8548cbd9491a36" "7f1d414afda803f3244c6fb4c2c64bea44dac040ed3731ec9d75275b9e831fe5" "69a259755bb4aee2c05bf8b9115b5b738fcdce5304dbb7818e9384a44d201b18" "5115d66a97d71daf02c6d34fcfd6427fbb4e39c3de3139888dd61f57d288753d" "965a3771dc9e844d05b460072f82e24db30b3b9256d3bf10d290bf8945137821" "d16a286583f7326bb1e3baf7d83df3643533cfa9ac6f0601d1b4a595ad2db523" "0d28873193ebbe12ecce0a0eb8dc808ffa352400e785c02992ed6d6773477c0d" "83afe95f30785201eb9e189bf507b0f38076a436804c987c52830214ac025906" "9ae0e81ced7c8d587cb1db9fcb528856315d352822082518884e8726fe681d1d" "601a9b9bf21f5c72ddfb28c7e95b842a5b0130f55ad5e0b97d2ba1e0b91b0a2c" "5062213da61cc87f29f4a117ecb4cfa85c9fe55a3281d6ba40246ca01fd08e1f" "b330e75c3717166db3a8a41eb180c705b46b97c584dffdb917b310f86025c811" "661d0eb8fa7cbfcc93b68047e7186caed97d2d48982ae5f1a938d31a55cd7df9" "062535e77813505521514d50abffc7ebc584e79004041be91c579a81fc7a3d35" "2fbb0cbdfff7c8a150b66f7537f9a23ad98107d98f2826c6c1dfaa2a3085c199" "a4853578a26cf51c2f70907c40597edf32a1914c58be345537ac3471544fc55d" "c730acdf0dfa1a919d7fe8cab427589f24150d5fa3715e205cb7bd94e0865dda" "6e995e092ec297b0919bc94b1bbf2936a668b5bbe7230dc3306bde69a6400aba" "ae1967910e7ce79efb0559b1f92e6249d3d0bb719d0335b24daf7ec861dbd0b1" "fb6ed924288a0bc476f21bab8f83dbc30e343833d8ad94a84e095a4b18ead1d5" "40798acf74d422d815f9c1d478440e01bc90d4971807d243767415bea128e71a" "0aebb395ae1889592594d1f5519f459dfb778304a8f2b7c4344f0c2e52b11c13" "44602e56a462a8c56597d87d57abe38948b3255ab1940ab2afd885309fad0436" "4ca16a4e1d915f78a5cd90b744b22dbc0507f62e8211724e9c7f86d672ac2df3" "6b0174fa9963275fd7f6181b0f706dc9546ede1df7361d410d9890652a148159" "9ce5b769ac6cf63c24e570c0092466db0ee473a7edfde1be518bf957322f738b" "3e200d49451ec4b8baa068c989e7fba2a97646091fd555eca0ee5a1386d56077" "8efa3d21b3fa1ac084798fae4e89848ec26ae5c724b9417caf4922f4b2e31c2a" "fd1dd4d022ece05400c7bd1efc2ae5cca5cd64a53f3670da49d0c8f0ef41f4e3" "f0c94bf6a29c232300e46af50f46ce337e721eacca6d618e8654a263db5ecdbe" "621595cbf6c622556432e881945dda779528e48bb57107b65d428e61a8bb7955" "e6ccd0cc810aa6458391e95e4874942875252cd0342efd5a193de92bfbb6416b" "45f7fec480eb3bdf364cbfcbc8d11ed0228bcf586ce7370fc30a6ce5770f181a" "01ce486c3a7c8b37cf13f8c95ca4bb3c11413228b35676025fdf239e77019ea1" "4af6fad34321a1ce23d8ab3486c662de122e8c6c1de97baed3aa4c10fe55e060" "83db918b06f0b1df1153f21c0d47250556c7ffb5b5e6906d21749f41737babb7" default))
 '(dabbrev-backward-only t)
 '(dabbrev-case-distinction nil)
 '(dabbrev-case-fold-search t)
 '(default-input-method "swedish-postfix")
 '(ediff-window-setup-function 'ediff-setup-windows-plain)
 '(eldoc-echo-area-use-multiline-p nil)
 '(eldoc-idle-delay 0.25)
 '(electric-indent-mode t)
 '(electric-pair-mode nil)
 '(evil-flash-delay 60)
 '(evil-motion-state-modes
   '(apropos-mode Buffer-menu-mode calendar-mode color-theme-mode command-history-mode dictionary-mode ert-results-mode help-mode Info-mode Man-mode speedbar-mode undo-tree-visualizer-mode view-mode woman-mode))
 '(grep-find-ignored-directories '(".svn" ".git" ".hg"))
 '(grep-find-ignored-files
   '(".#*" "*.o" "*~" "*.so" "*.a" "*.elc" "*.lib" "*.lo" "*.la" "*.pyc" "*.pyo"))
 '(helm-ag-insert-at-point 'symbol)
 '(helm-candidate-number-limit 10000)
 '(helm-follow-mode-persistent t)
 '(helm-source-names-using-follow '("Imenu" "AG" "Helm occur"))
 '(hide-ifdef-initially t)
 '(hide-ifdef-shadow t)
 '(initial-frame-alist '((fullscreen . maximized)))
 '(ispell-program-name "aspell")
 '(magit-log-arguments '("--graph" "--color" "--decorate" "-n256"))
 '(magit-log-auto-more t)
 '(magit-merge-arguments '("--no-ff"))
 '(magit-section-initial-visibility-alist '((stashes . show) (upstream . show)))
 '(magit-section-visibility-indicator '("" . t))
 '(magit-status-headers-hook
   '(magit-insert-error-header magit-insert-diff-filter-header magit-insert-repo-header magit-insert-head-branch-header magit-insert-upstream-branch-header magit-insert-push-branch-header magit-insert-tags-header))
 '(org-agenda-show-future-repeats nil)
 '(org-blank-before-new-entry '((heading . auto) (plain-list-item)))
 '(org-imenu-depth 3)
 '(org-modules '(ol-docview ol-info))
 '(org-refile-targets '((org-agenda-files :maxlevel . 3) (nil :maxlevel . 3)))
 '(org-use-fast-todo-selection 'expert)
 '(package-selected-packages
   '(bongo
     cape
     cmake-mode
     consult
     evil
     evil-leader
     evil-collection
     evil-numbers
     fancy-dabbrev
     expand-region
     gnuplot
     helm
     helm-ag
     hydra
     ledger-mode
     magit
     marginalia
     orderless
     ox-pandoc
     paredit
     reykjavik-theme
     soft-morning-theme
     terminal-here
     undo-tree
     vertico
     which-key
     yaml-mode))
 '(package-vc-selected-packages
   '((sandcastle-theme :vc-backend Git :url "https://github.com/habamax/sandcastle-theme")))
 '(project-vc-ignores '("./build/" "build/" ".#*" "*~" "*.elc" "*.pyc" "*.pyo"))
 '(read-quoted-char-radix 16)
 '(recentf-max-saved-items 1000)
 '(safe-local-variable-values
   '((my-input-method . swedish-postfix)
     (my-input-method . german-postfix)
     (tab-always-indent)
     (indent-tabs-mode nil)
     (evil-shift-width . 2)
     (evil-shift-width . 4)))
 '(tags-case-fold-search nil)
 '(terminal-here-linux-terminal-command 'gnome-terminal)
 '(terminal-here-mac-terminal-command 'iterm2)
 '(tramp-histfile-override "/tmp/.tramp_history")
 '(tramp-ssh-controlmaster-options
   "-o ControlMaster=auto -o ControlPath=tramp.%%C -o ControlPersist=60m" t)
 '(undo-tree-auto-save-history nil)
 '(warning-suppress-types '((comp))))

(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(flyspell-duplicate ((t (:background "Magenta" :foreground "white"))))
 '(flyspell-incorrect ((t (:background "red" :foreground "white"))))
 '(makefile-space ((t nil)))
 '(message-cited-text-1 ((t (:foreground "#878787"))))
 '(success ((t (:foreground "#00DD00" :weight bold)))))


