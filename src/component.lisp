;;; component.lisp --- ASDF component documentation

;; Copyright (C) 2010 Didier Verna

;; Author:        Didier Verna <didier@lrde.epita.fr>
;; Maintainer:    Didier Verna <didier@lrde.epita.fr>
;; Created:       Wed Aug 25 16:06:07 2010
;; Last Revision: Wed Aug 25 16:54:11 2010

;; This file is part of Declt.

;; Declt is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2 of the License, or
;; (at your option) any later version.

;; Declt is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.


;;; Commentary:


;;; Code:

(in-package :com.dvlsoft.declt)


(defvar *link-components* t
  "Whether to create links to components in the reference manual.
When true (the default), pathnames are made clickable but the links are
specific to this particular installation.

Setting this to NIL is preferable for creating reference manuals meant to put
online, and hence independent of any specific installation.")



;; ==========================================================================
;; Rendering Protocols
;; ==========================================================================

;; --------------------
;; Itemization protocol
;; --------------------

(defgeneric itemize (stream component)
  (:documentation "Render an itemized description of COMPONENT on STREAM.")
  (:method :before (stream (component asdf:component))
    (format stream "@item~%")
    (index stream component)
    (format stream "@t{~A} ("
      (component-name component)))
  (:method :after (stream (component asdf:component))
    (format stream "~@[, version ~A~])~%" (component-version component))))


;; ---------------------
;; Tableization protocol
;; ---------------------

(defmethod document (stream component &optional relative-to)
  (when (component-version component)
    (format stream "@item Version~%~A~%"
      (component-version component)))
  ;; #### NOTE: currently, we simply extract all the dependencies regardless
  ;; of the operations involved. We also assume that dependencies are of the
  ;; form (OP (OP DEP...) ...), but I'm not sure this is always the case.
  (let ((in-order-tos (slot-value component 'asdf::in-order-to))
	dependencies)
    (when in-order-tos
      (dolist (in-order-to in-order-tos)
	(dolist (op-dependency (cdr in-order-to))
	  (dolist (dependency (cdr op-dependency))
	    (pushnew dependency dependencies))))
      (format stream "@item Dependencies~%")
      (@itemize-list stream dependencies :format "@t{~(~A}~)")))
  (when (component-parent component)
    (format stream "@item Parent~%")
    (index stream (component-parent component))
    (format stream "@t{~A}~%"
      (component-name (component-parent component))))
  (cond ((eq (type-of component) 'asdf:system) ;; Yuck!
	 (when *link-components*
	   (format stream "@item Location~%@url{file://~A, ignore, ~A}~%"
	     (component-pathname component)
	     (component-pathname component)))
	 (let ((pathname (system-base-name component)))
	   (format stream "@item System File~%~
			   @lispfileindex{~A}@c~%~
			   ~:[@t{~;@url{file://~]~A}~%"
	     pathname
	     *link-components*
	     (if *link-components*
		 (format nil "~A, ignore, ~A"
		   (component-pathname component)
		   pathname)
	       pathname)))
	 (when *link-components*
	   (let ((directory (directory-namestring
			     (system-definition-pathname component))))
	     (format stream "@item Installation~%@url{file://~A, ignore, ~A}~%"
	       directory directory))))
	(t
	 (let ((pathname (enough-namestring (component-pathname component)
					    relative-to)))
	   (format stream "@item Location~%~:[@t{~;@url{file://~]~A}~%"
	     *link-components*
	     (if *link-components*
		 (format nil "~A, ignore, ~A"
		   (component-pathname component)
		   pathname)
	       pathname))))))


;;; component.lisp ends here
