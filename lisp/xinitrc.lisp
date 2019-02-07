;; things that used to be run by .xinitrc

(defun xmodmap-locate-file (&key
                              (hostname
                               (trim-spaces (run-shell-command "hostname" t)))
                              (xmodmap-dir #P"~/.xmodmap/"))
  (let* ((xmodmap-filename
           (loop for cand in (list hostname "default")
                 as pathname = (make-pathname
                                :name cand
                                :type "xmodmap"
                                :defaults
                                xmodmap-dir)
                 do (format t "xinitrc: value of pathname: ~A~%" pathname)
                   thereis (and (probe-file pathname)
                                pathname)))
         (host-specific-script (make-pathname :type "sh"
                                              :name hostname
                                              :defaults xmodmap-dir)))
    (values xmodmap-filename host-specific-script)))

(defun xmodmap-load ()
  (let ((xmodmap-pke "/tmp/xmodmap.pke"))
    (unless (probe-file xmodmap-pke)
      (run-shell-command (format nil "xmodmap -pke > ~A" xmodmap-pke) t)))

  (multiple-value-bind (xmodmap-filename host-specific-script)
      (xmodmap-locate-file)
    (assert xmodmap-filename)
    (when (probe-file host-specific-script)
      (run-shell-command (format nil "bash ~A" host-specific-script)))
    (loop for _ below 4
          as cmd = (format nil "xmodmap -verbose ~A" xmodmap-filename)
          do (run-shell-command cmd t)
          do (sleep .5))))

(defun run-startup-scripts ()
  (loop for script in (append
                       '(#P"~/.xsessionrc")
                       (directory #P"~/.stumpwmrc.d/scripts/on-startup/*.*"))
        do (format t "running script ~A~%" script)
        do
           (run-shell-command (format nil "~A &" script) nil)))

(defvar *screensaver-proc* nil)
(defparameter *screensaver-lock-time-mins* 15)

(defun screen-lock-program ()
  (or (which "xsecurelock.sh")
      (which "xsecurelock")))

(defun start-screensaver ()
  (let ((lock-program (screen-lock-program)))
    (unless (and lock-program
                 (which "xautolock"))
      (error "xsecurelock, xautolock not installed"))
    (unless (and *screensaver-proc*
                 (eq :RUNNING (slot-value *screensaver-proc* 'SB-IMPL::%STATUS)))
      (setf *screensaver-proc*
            ;; "xautolock -time 1 -locker xsecurelock"
            (SB-EXT:RUN-PROGRAM "xautolock"
                                (list "-time" (write-to-string *screensaver-lock-time-mins*)
                                      "-locker" lock-program)
                                :environment (cons "XSECURELOCK_WANT_FIRST_KEYPRESS=1"
                                                   (sb-ext:posix-environ))
                                :search t
                                :output t
                                :error t
                                :wait nil)))))

(unless (fboundp 'with-elapsed-time)
  (defmacro with-elapsed-time (var timed-form post-form)
    (declare (ignore var post-form))
    timed-form))

(unless (fboundp 'run-shell-command)
  (defun run-shell-command (cmd &optional sync)
    (declare (ignore sync))
    (with-output-to-string (s)
      (sb-ext:run-program "bash"
                          (list "-c" cmd)
                          :search t
                          :wait t
                          :output s)
      s)))

(unless (fboundp 'trim-spaces)
  (defun trim-spaces (str)
    (string-trim '(#\space #\tab #\newline) str)))

(unless (fboundp 'which)
  (defun which (program)
    (trim-spaces (run-shell-command
                  (format nil "which ~A" program)))))

(with-elapsed-time ms (xmodmap-load)
  (message "xmodmap load took ~D ms" ms))

(with-elapsed-time ms (run-startup-scripts)
  (message "startup shell scripts took ~D ms" ms))

(with-elapsed-time ms (start-screensaver)
  (message "screensaver load took ~D ms" ms))
