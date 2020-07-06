(defpackage cladaver
  (:use :cl :statusor)
  (:export
   #:make-server-info
   #:ls
   #:cat
   #:put))

(in-package #:cladaver)

(defstruct server-info
  base-url username password)

(defun ls (info path)
  (with-slots (base-url) info
    (if-let-ok nil
        ((url (format nil "~A~A" base-url path))
         (raw-resp
          (http-request-or-error url
                                 :method :PROPFIND
                                 :additional-headers '(("Depth" . "1"))))
         (doc (cxml:parse raw-resp (stp:make-builder)))
         (nodeset
          (xpath:with-namespaces (("D" "DAV:"))
            (xpath:evaluate "//D:href/text()" doc)))
         (iter (xpath:make-node-set-iterator nodeset)))
      (loop
         with first = nil
         while (not (xpath:node-set-iterator-end-p iter))
         for i from 0
         as node = (xpath:node-set-iterator-current iter)
         as pathname = (pathname (cxml-stp:data node))
         as basename = (pathname-name pathname)
         do (assert (if (zerop i)
                        (prog1
                            (null basename)
                          (setf first pathname))
                        (equal (pathname-directory first)
                               (pathname-directory pathname))))
         unless (null basename)
         collect pathname
         do (setf iter (xpath:node-set-iterator-next iter))))))

(defun cat (info path)
  (with-slots (base-url) info
    (if-let-ok nil
        ((url (format nil "~A~A" base-url path))
         (raw-resp
          (http-request-or-error url :method :GET))
         (string (if (stringp raw-resp)
                     raw-resp
                     (babel:octets-to-string raw-resp))))
      string)))

(defun put (info path data)
  (with-slots (base-url) info
    (if-let-ok nil
        ((url (format nil "~A~A" base-url path))
         (raw-resp
          (http-request-or-error url
                                 :method :PUT
                                 :content data)))
      raw-resp)))
