;;; symbol.lisp --- Symbol based items

;; Copyright (C) 2010, 2011, 2012 Didier Verna

;; Author:        Didier Verna <didier@lrde.epita.fr>
;; Maintainer:    Didier Verna <didier@lrde.epita.fr>

;; This file is part of Declt.

;; Declt is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License version 3,
;; as published by the Free Software Foundation.

;; Declt is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.


;;; Commentary:

;; Contents management by FCM version 0.1.


;;; Code:

(in-package :com.dvlsoft.declt)
(in-readtable :com.dvlsoft.declt)


;; ==========================================================================
;; Definitions
;; ==========================================================================

;; ----------
;; Categories
;; ----------

;; #### NOTE: when constructing the context lists of external and internal
;; definitions, only the definitions listed in +CATEGORIES+ appear. This is
;; because these lists follow the structure of the Definitions chapter in the
;; generated manual. For instance, methods are listed under the corresponding
;; generic function, so they don't represent a category of its own.

;; #### NOTE: the order in +CATEGORIES+ is important (see
;; ADD-CATEGORIES-NODE). It conditions the order of appearance of the
;; definitions in the generated manual.

(define-constant +categories+
    '((:constant       "constants")
      (:special        "special variables")
      (:symbol-macro   "symbol macros")
      (:macro          "macros")
      (:compiler-macro "compiler macros")
      (:function       "functions")
      (:generic        "generic functions")
      (:combination    "method combinations")
      (:condition      "conditions")
      (:structure      "structures")
      (:class          "classes")
      (:type           "types"))
  "The list of definition categories.
Each category is of type (:KEYWORD DESCRIPTION-STRING).")


;; -----------
;; Definitions
;; -----------

;; #### NOTE: writer structures (either regular or generic) don't store the
;; complete function name (setf <name>) but only the original symbol. This, in
;; conjunction with the fact that definitions are sorted by symbol-name,
;; ensures that standalone writers (not associated with readers) are listed in
;; proper lexicographic order regardless of the SETF part of their name
;; (although that part still appears in the documentation).

(defstruct definition
  "Base structure for definitions named by symbols.
This structure holds the symbol naming the definition."
  symbol)

(defstruct (constant-definition (:include definition))
  "Structure for constant definitions.")
(defstruct (special-definition (:include definition))
  "Structure for special variables definitions.")
(defstruct (symbol-macro-definition (:include definition))
  "Structure for symbol macro definitions.")

(defstruct (funcoid-definition (:include definition))
  "Base structure for definitions of functional values.
This structure holds the the function, generic function or macro function
object, and a potential setf expander definition (short form) or function
object (long form)."
  function
  ;; #### NOTE: technically, it's not quite correct to have this slot here
  ;; because not all funcoids can have a setf expander (compiler macros
  ;; don't). However, it simplifies the writing of FINALIZE-DEFINITIONS
  ;; towards the end of this file. With a SETF-EXPANDER slot here, I can
  ;; batch-process macros, functions and generics all at once using the same
  ;; slot accessor.
  setf-expander)

(defstruct (macro-definition (:include funcoid-definition))
  "Structure for macro definitions.")
(defstruct (compiler-macro-definition (:include funcoid-definition))
  "Structure for compiler macro definitions.")

(defstruct (function-definition (:include funcoid-definition))
  "Structure for ordinary function definitions.
This structure holds a slot for marking foreign definitions, i.e. those which
do pertain to the system being documented."
  foreignp)
(defstruct (writer-definition (:include function-definition))
  "Structure for ordinary writer function definitions.")
(defstruct (accessor-definition (:include function-definition))
  "Structure for accessor function definitions.
This structure holds the writer function definition."
  writer)

(defstruct (method-definition (:include definition))
  "Base structure for method definitions.
This structure holds the method object and also a slot for marking foreign
definitions, i.e. those which do pertain to the system being documented."
  foreignp
  method)
(defstruct (writer-method-definition (:include method-definition))
  "Structure for writer method definitions.")
(defstruct (accessor-method-definition (:include method-definition))
  "Structure for accessor method definitions.
This structure holds the writer method definition."
  writer)

(defstruct (generic-definition (:include funcoid-definition))
  "Structure for generic function definitions.
This structure holds the combination definition, the list of method
definitions and also a slot for marking foreign definitions, i.e. those which
do pertain to the system being documented."
  foreignp
  combination
  methods)
(defstruct (generic-writer-definition (:include generic-definition))
  "Structure for generic writer function definitions.")
(defstruct (generic-accessor-definition (:include generic-definition))
  "Structure for generic accessor function definitions.
This structure holds the generic writer function definition."
  writer)

(defstruct (slot-definition (:include definition))
  "Structure for slot definitions.
This structure holds the slot object and the readers and writers definitions."
  slot
  readers
  writers)

(defstruct (combination-definition (:include definition))
  "Structure for method combination definitions.
This structure holds the method combination object and a list of users, that
is, generic functions using this method combination."
  foreignp
  combination
  users)

(defstruct (short-combination-definition (:include combination-definition))
  "Structure for short method combination definitions.
This structure holds the operator definition."
  operator)

(defstruct (long-combination-definition (:include combination-definition))
  "Structure for long method combination definitions.")


(defstruct (classoid-definition (:include definition))
  "Base structure for class-like (supporting inheritance) values.
This structure holds links to the direct ancestors and descendants
definitions, direct methods definitions, direct slots, and also a slot for
marking foreign definitions, i.e. those which do pertain to the system being
documented. Foreign definitions may appear as part of an inheritance
documentation."
  foreignp
  parents
  children
  methods
  slots)
(defstruct (condition-definition (:include classoid-definition))
  "Structure for condition definitions.")
(defstruct (structure-definition (:include classoid-definition))
  "Structure for structure definition.")
(defstruct (class-definition (:include classoid-definition))
  "Structure for class definitions.
This structure holds the direct superclasses and direct subclasses
definitions.")
(defstruct (type-definition (:include definition))
  "Structure for type definitions.")

;; #### PORTME.
(defgeneric lambda-list (definition)
  (:documentation "Return DEFINITION's lambda-list.")
  (:method ((funcoid funcoid-definition))
    "Return FUNCOID's lambda-list."
    (sb-introspect:function-lambda-list
     (funcoid-definition-function funcoid)))
  (:method ((method method-definition))
    "Return METHOD's lambda-list."
    (sb-mop:method-lambda-list (method-definition-method method)))
  (:method ((type type-definition))
    "Return TYPE's lambda-list."
    (sb-introspect:deftype-lambda-list (definition-symbol type))))


;; #### PORTME.
(defun specializers (method)
  "Return METHOD's specializers."
  (sb-mop:method-specializers (method-definition-method method)))

;; #### PORTME.
(defun qualifiers (method)
  "Return METHOD's qualifiers."
  (method-qualifiers (method-definition-method method)))


;; ----------------
;; Definition pools
;; ----------------

(defun make-definitions-pool ()
  "Create and return a new definitions pool.
A definitions pool is a hash table of categorized definitions.
Keys must be of the form (NAME :CATEGORY).
  - NAME is the symbol naming the definition,
  - :CATEGORY is one listed in +CATEGORIES+."
  (make-hash-table :test 'equal))

(defun definitions-pool-size (pool)
  "Return the number of elements in definitions POOL."
  (hash-table-count pool))

(defun mapcan-definitions-pool (function pool)
  "Like MAPCAN, but work on a definitions POOL."
  (loop :for definition :being :the :hash-values :in pool
	:nconc (funcall function definition)))

(defgeneric find-definition (name category pool &optional errorp)
  (:documentation "Find a CATEGORY definition for NAME in POOL.
If ERRORP, throw an error if not found. Otherwise, just return NIL.")
  (:method (name category pool
	    &optional errorp
	    &aux (definition (gethash (list name category) pool)))
    "Default method used for root CATEGORYs"
    (or definition
	(when errorp
	  (error "No ~A definition found for symbol ~A" category name))))
  (:method (name (category (eql :generic-writer)) pool
	    &optional errorp
	    &aux (definition (find-definition name :generic pool errorp)))
    "Method used to find generic writer definitions.
Name must be that of the reader (not the SETF form)."
    (or (typecase definition
	  (generic-writer-definition
	   definition)
	  (generic-accessor-definition
	   (generic-accessor-definition-writer definition)))
	(when errorp
	  (error "No generic writer definition found for symbol ~A" name))))
  (:method (name (category (eql :writer)) pool
	    &optional errorp
	    &aux (definition (find-definition name :function pool errorp)))
    "Method used to find writer definitions.
Name must be that of the reader (not the SETF form)."
    (or (typecase definition
	  (writer-definition
	   definition)
	  (accessor-definition
	   (accessor-definition-writer definition)))
	(when errorp
	  (error "No writer definition found for symbol ~A." name)))))

;; #### PORTME.
(defun method-name (method
		    &aux (name (sb-mop:generic-function-name
				(sb-mop:method-generic-function method))))
  "Return METHOD's name.
Return a second value of T if METHOD is a writer method."
  (if (listp name)
      (values (second name) t)
    name))

(defun find-method-definition (method pool)
  "Find a method definition for METHOD in POOL.
Return NIL if not found."
  (multiple-value-bind (name writerp) (method-name method)
    (let ((generic (find-definition name :generic pool)))
      (when generic
	(cond (writerp
	       (etypecase generic
		 (generic-writer-definition
		  (find method (generic-definition-methods generic)
			:key #'method-definition-method))
		 (generic-accessor-definition
		  (find method (generic-definition-methods
				(generic-accessor-definition-writer generic))
			:key #'method-definition-method))))
	      (t
	       (find method (generic-definition-methods generic)
		     :key #'method-definition-method)))))))

(defgeneric category-definitions (category pool)
  (:documentation "Return all CATEGORY definitions from POOL.")
  (:method (category pool)
    "Default method used for root CATEGORYs."
    (loop :for key   :being :the :hash-keys   :in pool
	  :for value :being :the :hash-values :in pool
	  :when (eq (second key) category)
	    :collect value))
  (:method ((category (eql :short-combination)) pool)
    "Method used for short method combinations."
    (loop :for key   :being :the :hash-keys   :in pool
	  :for value :being :the :hash-values :in pool
	  :when (and (eq (second key) :combination)
		     (short-combination-definition-p value))
	    :collect value))
  (:method ((category (eql :long-combination)) pool)
    "Method used for long method combinations."
    (loop :for key   :being :the :hash-keys   :in pool
	  :for value :being :the :hash-values :in pool
	  :when (and (eq (second key) :combination)
		     (long-combination-definition-p value))
	    :collect value)))

(defun add-definition (symbol category definition pool)
  "Add CATEGORY kind of DEFINITION for SYMBOL to POOL."
  (setf (gethash (list symbol category) pool) definition))

(defun make-slot-definitions (class)
  "Return a list of direct slot definitions for CLASS."
  (mapcar (lambda (slot)
	    (make-slot-definition
	     :symbol (sb-mop:slot-definition-name slot)
	     :slot slot))
	  (sb-mop:class-direct-slots class)))

;; #### PORTME.
(defun add-symbol-definition (symbol category pool)
  "Add and return the CATEGORY kind of definition for SYMBOL to pool, if any."
  (or (find-definition symbol category pool)
      (ecase category
	(:constant
	 (when (eql (sb-int:info :variable :kind symbol) :constant)
	   (add-definition
	    symbol category (make-constant-definition :symbol symbol) pool)))
	(:special
	 (when (eql (sb-int:info :variable :kind symbol) :special)
	   (add-definition
	    symbol category (make-special-definition :symbol symbol) pool)))
	(:symbol-macro
	 (when (eql (sb-int:info :variable :kind symbol) :macro)
	   (add-definition
	    symbol category
	    (make-symbol-macro-definition :symbol symbol) pool)))
	(:macro
	 (let ((function (macro-function symbol)))
	   (when function
	     (add-definition
	      symbol
	      category
	      (make-macro-definition :symbol symbol :function function)
	      pool))))
	(:compiler-macro
	 (let ((function (compiler-macro-function symbol)))
	   (when function
	     (add-definition
	      symbol
	      category
	      (make-compiler-macro-definition :symbol symbol
					      :function function)
	      pool))))
	(:function
	 (let ((function
		 (when (and (fboundp symbol)
			    (not (macro-function symbol))
			    (not (typep (fdefinition symbol)
					'generic-function)))
		   (fdefinition symbol)))
	       (writer
		 (let ((writer-name `(setf ,symbol)))
		   (when (and (fboundp writer-name)
			      (not (typep (fdefinition writer-name)
					  'generic-function)))
		     (fdefinition writer-name)))))
	   (cond ((and function writer)
		  (add-definition
		   symbol
		   category
		   (make-accessor-definition
		    :symbol symbol
		    :function function
		    :writer (make-writer-definition
			     :symbol symbol
			     :function writer))
		   pool))
		 (function
		  (add-definition
		   symbol
		   category
		   (make-function-definition :symbol symbol
					     :function function)
		   pool))
		 (writer
		  (add-definition
		   symbol
		   category
		   (make-writer-definition :symbol symbol
					   :function writer)
		   pool)))))
	(:generic
	 (let ((function
		 (when (and (fboundp symbol)
			    (typep (fdefinition symbol) 'generic-function))
		   (fdefinition symbol)))
	       (writer
		 (let ((writer-name `(setf ,symbol)))
		   (when (and (fboundp writer-name)
			      (typep (fdefinition writer-name)
				     'generic-function))
		     (fdefinition writer-name)))))
	   (cond ((and function writer)
		  ;; #### NOTE: for a generic accessor function, we store
		  ;; accessor methods in the generic accessor function
		  ;; definition, along with standard methods. Only writer-only
		  ;; methods are stored in the generic writer function
		  ;; definition.
		  (add-definition
		   symbol
		   category
		   (make-generic-accessor-definition
		    :symbol symbol
		    :function function
		    :methods
		    (mapcar
		     (lambda (method)
		       (let ((writer-method
			       (find-method writer
					    (method-qualifiers method)
					    ;; #### FIXME: I'm not sure if the
					    ;; first argument (NEW-VALUE) of a
					    ;; writer method always has a
					    ;; specializer of T...
					    (cons t
						  (sb-mop:method-specializers
						   method))
					    nil)))
			 (if writer-method
			     (make-accessor-method-definition
			      :symbol symbol
			      :method method
			      :writer (make-writer-method-definition
				       :symbol symbol
				       :method writer-method))
			   (make-method-definition
			    :symbol symbol :method method))))
		     (sb-mop:generic-function-methods function))
		    :writer (make-generic-writer-definition
			     :symbol symbol
			     :function writer
			     :methods
			     (mapcan
			      (lambda (method)
				(unless (find-method function
						     (method-qualifiers method)
						     ;; #### NOTE: don't
						     ;; forget to remove the
						     ;; first (NEW-VALUE)
						     ;; specializer from the
						     ;; writer method.
						     (cdr
						      (sb-mop:method-specializers
						       method))
						     nil)
				  (list (make-writer-method-definition
					 :symbol symbol
					 :method method))))
			      (sb-mop:generic-function-methods writer))))
		   pool))
		 (function
		  (add-definition
		   symbol
		   category
		   (make-generic-definition
		    :symbol symbol
		    :function function
		    :methods (mapcar (lambda (method)
				       (make-method-definition :symbol symbol
							       :method method))
				     (sb-mop:generic-function-methods
				      function)))
		   pool))
		 (writer
		  (add-definition
		   symbol
		   category
		   (make-generic-writer-definition
		    :symbol symbol
		    :function writer
		    :methods (mapcar (lambda (method)
				       (make-writer-method-definition
					:symbol symbol
					:method method))
				     (sb-mop:generic-function-methods
				      writer)))
		   pool)))))
	;; #### WARNING: the method combination interface is probably the
	;; ugliest thing I know about Common Lisp. The problem is that the
	;; relation NAME <-> COMBINATION is not bijective. Generic functions
	;; created with a named method combination get the current definition
	;; for this name, and it becomes local. Subsequent redefinitions of a
	;; method combination of that name will not affect them; only newly
	;; defined generic functions.
	;;
	;; As a result, there is in fact no such thing as "the method
	;; combination named BLABLA". Here's how SBCL works with this mess.
	;; When you call DEFINE-METHOD-COMBINATION, SBCL creates a new method
	;; for FIND-METHOD-COMBINATION. This method is encapsulated in a
	;; closure containing the method combination's definition, ignores its
	; first argument and recreates a method combination object on the fly.
	;; In order to get this object, you may hence call
	;; FIND-METHOD-COMBINATION with whatever generic function you wish.
	;;
	;; Consequence for Declt: normally, it's impossible to provide a list
	;; of global method combinations. Every generic function can
	;; potentially have one with the same name as another. The proper way
	;; to retrieve a method combination per generic function is to call
	;; GENERIC-FUNCTION-METHOD-COMBINATION. In Declt however, I will make
	;; the assumption that the programmer has some sanity and only defines
	;; one method combination for every name. The corresponding object
	;; will be documented like the other ones. In generic function
	;; documentations, there will be a reference to the method combination
	;; and only the method combination options will be documented there,
	;; as they may be generic function specific.
	(:combination
	 (let* ((method (find-method #'sb-mop:find-method-combination
				     nil
				     `(,(find-class 'generic-function)
				       (eql ,symbol)
				       t)
				     nil))
		(combination (when method
			       (sb-mop:find-method-combination
				;; #### NOTE: we could use any generic
				;; function instead of DOCUMENTATION here.
				;; Also, NIL options don't matter because they
				;; are not advertised as part of the method
				;; combination, but as part of the generic
				;; functions that use them.
				#'documentation symbol nil))))
	   (when combination
	     (add-definition
	      symbol
	      category
	      (etypecase combination
		(sb-pcl::short-method-combination
		 (make-short-combination-definition
		  :symbol symbol
		  :combination combination))
		(sb-pcl::long-method-combination
		 (make-long-combination-definition
		  :symbol symbol
		  :combination combination)))
	      pool))))
	(:condition
	 (let ((class (find-class symbol nil)))
	   (when (and class (typep class 'sb-pcl::condition-class))
	     (add-definition
	      symbol
	      category
	      (make-condition-definition
	       :symbol symbol
	       :slots (make-slot-definitions class))
	      pool))))
	(:structure
	 (let ((class (find-class symbol nil)))
	   (when (and class (typep class 'sb-pcl::structure-class))
	     (add-definition
	      symbol
	      category
	      (make-structure-definition
	       :symbol symbol
	       :slots (make-slot-definitions class))
	      pool))))
	(:class
	 (let ((class (find-class symbol nil)))
	   (when (and class
		      (not (add-symbol-definition symbol :condition pool))
		      (not (add-symbol-definition symbol :structure pool)))
	     (add-definition
	      symbol
	      category
	      (make-class-definition
	       :symbol symbol
	       :slots (make-slot-definitions class))
	      pool))))
	(:type
	 (when (eql (sb-int:info :type :kind symbol) :defined)
	   (add-definition
	    symbol
	    category
	    (make-type-definition :symbol symbol)
	    pool))))))

(defun add-symbol-definitions (symbol pool)
  "Add all categorized definitions for SYMBOL to POOL."
  (dolist (category +categories+)
    (add-symbol-definition symbol (first category) pool)))

;; #### PORTME.
(defun slot-property (slot property)
  "Return SLOT definition's PROPERTY value."
  (funcall
   (intern (concatenate 'string "SLOT-DEFINITION-" (symbol-name property))
	   :sb-mop)
   slot))

(defgeneric reader-definitions (slot pool1 pool2)
  (:documentation "Return a list of reader definitions for SLOT.")
  (:method (slot pool1 pool2)
    "Defaut method for class and condition slots."
    (mapcar
     (lambda (reader-name)
       (or (find-definition reader-name :generic pool1)
	   (find-definition reader-name :generic pool2)
	   (make-generic-definition :symbol reader-name :foreignp t)))
     (slot-property slot :readers)))
  ;; #### PORTME.
  (:method ((slot sb-pcl::structure-direct-slot-definition) pool1 pool2)
    "Method for structure slots."
    (list
     (let ((reader-name
	     (sb-pcl::slot-definition-defstruct-accessor-symbol slot)))
       (or (find-definition reader-name :function pool1)
	   (find-definition reader-name :function pool2)
	   (make-generic-definition :symbol reader-name :foreignp t))))))

(defgeneric writer-definitions (slot pool1 pool2)
  (:documentation "Return a list of writer definitions for SLOT.")
  (:method (slot pool1 pool2)
    "Default method for class and condition slots."
    (mapcar
     (lambda (writer-name &aux (writer-name (second writer-name)))
       (or (find-definition writer-name :generic-writer pool1)
	   (find-definition writer-name :generic-writer pool2)
	   (make-generic-writer-definition :symbol writer-name :foreignp t)))
     (slot-property slot :writers)))
  ;; #### PORTME.
  (:method ((slot sb-pcl::structure-direct-slot-definition) pool1 pool2)
    "Method for structure slots."
    (list
     (let ((writer-name
	     (sb-pcl::slot-definition-defstruct-accessor-symbol slot)))
       (or (find-definition writer-name :writer pool1)
	   (find-definition writer-name :writer pool2)
	   (make-writer-definition :symbol writer-name :foreignp t))))))

;; #### PORTME.
(defgeneric definition-combination-users (definition combination)
  (:documentation "Return a list of definitions using method COMBINATION.
The list may boil down to a generic function definition, but may also contain
both a reader and a writer.")
  (:method (definition combination)
    "Default method, for non generic function definitions.
Return nil."
    nil)
  (:method ((definition generic-definition) combination)
    "Method for simple generic and writer definitions."
    (when (eq (sb-pcl::method-combination-type-name
	       (sb-mop:generic-function-method-combination
		(generic-definition-function definition)))
	      combination)
      (list definition)))
  (:method ((definition generic-accessor-definition) combination)
    "Method for generic accessor definitions."
    (nconc (call-next-method)
	   (definition-combination-users
	    (generic-accessor-definition-writer definition) combination))))

(defun pool-combination-users (pool combination)
  "Return a list of all generic definitions in POOL using method COMBINATION."
  (mapcan-definitions-pool
   (lambda (definition) (definition-combination-users definition combination))
   pool))

;; #### NOTE: this finalization step is required for two reasons:
;;   1. it makes it easier to handle cross references (e.g. class inheritance)
;;      because at that time, we know that all definitions have been created,
;;   2. it also makes it easier to handle foreign definitions (that we don't
;;      want to add in the definitions pools) bacause at that time, we know
;;      that if a definition doesn't exist in the pools, then it is foreign.
;; #### PORTME.
(defun finalize-definitions (pool1 pool2)
  "Finalize the definitions in POOL1 and POOL2.
Currently, this means resolving:
- classes subclasses,
- classes superclasses,
- classes direct methods,
- slots readers,
- slots writers,
- generic functions method combinations,
- method combinations operators (for short ones) and users (for both),
- (generic) functions and macros setf expanders."
  (labels ((classes-definitions (classes)
	     (mapcar
	      (lambda (name)
		;; #### NOTE: documenting inheritance works here because SBCL
		;; uses classes for reprensenting structures and conditions,
		;; which is not required by the standard. It also means that
		;; there may be intermixing of conditions, structures and
		;; classes in inheritance graphs, so we need to handle that.
		(or  (find-definition name :class pool1)
		     (find-definition name :class pool2)
		     (find-definition name :structure pool1)
		     (find-definition name :structure pool2)
		     (find-definition name :condition pool1)
		     (find-definition name :condition pool2)
		     (make-classoid-definition :symbol name :foreignp t)))
	      (reverse (mapcar #'class-name classes))))
	   (methods-definitions (methods)
	     (mapcar
	      (lambda (method)
		(or  (find-method-definition method pool1)
		     (find-method-definition method pool2)
		     (make-method-definition :symbol (method-name method)
					     :foreignp t)))
	      methods))
	   (compute-combination (generic)
	     (let ((name (sb-pcl::method-combination-type-name
			  (sb-mop:generic-function-method-combination
			   (generic-definition-function generic)))))
	       (setf (generic-definition-combination generic)
		     (or (find-definition name :combination pool1)
			 (find-definition name :combination pool2)
			 (make-combination-definition :symbol name
						      :foreignp t)))))
	   (finalize (pool)
	     (dolist (category '(:class :structure :condition))
	       (dolist (definition (category-definitions category pool))
		 (let ((class (find-class (definition-symbol definition))))
		   (setf (classoid-definition-parents definition)
			 (classes-definitions
			  (sb-mop:class-direct-superclasses class)))
		   (setf (classoid-definition-children definition)
			 (classes-definitions
			  (sb-mop:class-direct-subclasses class)))
		   (setf (classoid-definition-methods definition)
			 (methods-definitions
			  (sb-mop:specializer-direct-methods class)))
		   (dolist (slot (classoid-definition-slots definition))
		     (setf (slot-definition-readers slot)
			   (reader-definitions
			    (slot-definition-slot slot) pool1 pool2))
		     (setf (slot-definition-writers slot)
			   (writer-definitions
			    (slot-definition-slot slot) pool1 pool2))))))
	     (dolist (generic (category-definitions :generic pool))
	       (compute-combination generic)
	       (when (generic-accessor-definition-p generic)
		 (compute-combination
		  (generic-accessor-definition-writer generic))))
	     (dolist
		 (combination (category-definitions :short-combination pool))
	       (let ((operator (sb-pcl::short-combination-operator
				(combination-definition-combination
				 combination))))
		 (setf (short-combination-definition-operator combination)
		       (or (find-definition operator :function pool1)
			   (find-definition operator :function pool2)
			   (find-definition operator :macro pool1)
			   (find-definition operator :macro pool2)
			   ;; #### NOTE: a foreign operator is not necessarily
			   ;; a function. It could be a macro or a special
			   ;; form. However, since we don't actually document
			   ;; those (only print their name), we can just use a
			   ;; function definition here (it's out of laziness)
			   (make-function-definition :symbol operator
						     :foreignp t))))
	       (setf (combination-definition-users combination)
		     (nconc (pool-combination-users
			     pool1 (definition-symbol combination))
			    (pool-combination-users
			     pool2 (definition-symbol combination)))))
	     (dolist
		 (combination (category-definitions :long-combination pool))
	       (setf (combination-definition-users combination)
		     (nconc (pool-combination-users
			     pool1 (definition-symbol combination))
			    (pool-combination-users
			     pool2 (definition-symbol combination)))))
	     (dolist (category '(:macro :function :generic))
	       (dolist (definition (category-definitions category pool))
		 (let ((expander (or (sb-int:info :setf :inverse
				       (definition-symbol definition))
				     (sb-int:info :setf :expander
				       (definition-symbol definition)))))
		   (cond ((and expander (symbolp expander))
			  (setf
			   (funcoid-definition-setf-expander definition)
			   (or (find-definition expander :function pool1)
			       (find-definition expander :function pool2)
			       (find-definition expander :generic pool1)
			       (find-definition expander :generic pool2)
			       (find-definition expander :macro pool1)
			       (find-definition expander :macro pool2)
			       ;; #### NOTE: a foreign expander is not
			       ;; necessarily a function. It could be a
			       ;; macro or a special form. However, since
			       ;; we don't actually document those (only
			       ;; print their name), we can just use a
			       ;; function definition here (it's out of
			       ;; laziness)
			       (make-function-definition :symbol expander
							 :foreignp t))))
			 ((functionp expander)
			  (setf
			   (funcoid-definition-setf-expander definition)
			   expander))))))))
    (finalize pool1)
    (finalize pool2)))



;; ==========================================================================
;; Rendering protocols
;; ==========================================================================

(defmethod name ((definition definition))
  "Return DEFINITION's symbol name."
  (name (definition-symbol definition)))

;; #### NOTE: all of these methods are in fact equivalent. That's the drawback
;; of using structures instead of classes, which limits the inheritance
;; expressiveness (otherwise I could have used a writer mixin or something).
(defmethod name ((writer writer-definition))
  "Return WRITER's name, that is (setf <name>)."
  (format nil "(SETF ~A)" (name (writer-definition-symbol writer))))

(defmethod name ((writer-method writer-method-definition))
  "Return WRITER-METHOD's name, that is (setf <name>)."
  (format nil "(SETF ~A)"
    (name (writer-method-definition-symbol writer-method))))

(defmethod name ((generic-writer generic-writer-definition))
  "Return GENERIC-WRITER's name, that is (setf <name>)."
  (format nil "(SETF ~A)"
    (name (generic-writer-definition-symbol generic-writer))))



;; ==========================================================================
;; Item Protocols
;; ==========================================================================

;; ---------------
;; Source protocol
;; ---------------

;; #### NOTE: SB-INTROSPECT:FIND-DEFINITION-SOURCES-BY-NAME may return
;; multiple sources (e.g. if we were to ask it for methods) so we take the
;; first one. That is okay because we actually use it only when there can be
;; only one definition source.
;; #### PORTME.
(defun definition-source-by-name
    (definition type
     &key (name (definition-symbol definition))
     &aux (defsrc (car (sb-introspect:find-definition-sources-by-name
			name type))))
  "Return DEFINITION's source for TYPE."
  (when defsrc
    (sb-introspect:definition-source-pathname defsrc)))

;; #### PORTME.
(defun definition-source
    (object &aux (defsrc (sb-introspect:find-definition-source object)))
  "Return OBJECT's definition source."
  (when defsrc
    (sb-introspect:definition-source-pathname defsrc)))


(defmethod source ((constant constant-definition))
  "Return CONSTANT's definition source."
  (definition-source-by-name constant :constant))

(defmethod source ((special special-definition))
  "Return SPECIAL's definition source."
  (definition-source-by-name special :variable))

(defmethod source ((symbol-macro symbol-macro-definition))
  "Return SYMBOL-MACRO's definition source."
  (definition-source-by-name symbol-macro :symbol-macro))

(defmethod source ((funcoid funcoid-definition))
  "Return FUNCOID's definition source."
  (definition-source (funcoid-definition-function funcoid)))

(defmethod source ((method method-definition))
  "Return METHOD's definition source."
  (definition-source (method-definition-method method)))

;; #### NOTE: no SOURCE method for SLOT-DEFINITION.

(defmethod source ((combination combination-definition))
  "Return method COMBINATION's definition source."
  (definition-source-by-name combination :method-combination))

(defmethod source ((condition condition-definition))
  "Return CONDITION's definition source."
  (definition-source-by-name condition :condition))

(defmethod source ((structure structure-definition))
  "Return STRUCTURE's definition source."
  (definition-source-by-name structure :structure))

(defmethod source ((class class-definition))
  "Return CLASS's definition source."
  (definition-source-by-name class :class))

(defmethod source ((type type-definition))
  "Return TYPE's definition source."
  (definition-source-by-name type :type))


;; ---------------
;; Source protocol
;; ---------------

(defmethod docstring ((constant constant-definition))
  "Return CONSTANT's docstring."
  (documentation (definition-symbol constant) 'variable))

(defmethod docstring ((special special-definition))
  "Return SPECIAL variable's docstring."
  (documentation (definition-symbol special) 'variable))

;; #### NOTE: normally, we shouldn't have to define this because the DOCUMENT
;; method on symbol macros should just not try to get the documentation.
;; However, we do because it allows us to reuse existing code, notably
;; RENDER-@DEFVAROID and hence RENDER-DEFINITION-CORE, and perform the same
;; stuff as for constants and variables.
(defmethod docstring ((symbol-macro symbol-macro-definition))
  "Return NIL because symbol macros don't have a docstring."
  (declare (ignore symbol-macro))
  nil)

(defmethod docstring ((funcoid funcoid-definition))
  "Return FUNCOID's docstring."
  (documentation (definition-symbol funcoid) 'function))

(defmethod docstring ((compiler-macro compiler-macro-definition))
  "Return COMPILER-MACRO's docstring."
  (documentation (definition-symbol compiler-macro) 'compiler-macro))

(defmethod docstring ((writer writer-definition))
  "Return WRITER's docstring."
  (documentation `(setf ,(definition-symbol writer)) 'function))

(defmethod docstring ((method method-definition))
  "Return METHOD's docstring."
  (documentation (method-definition-method method) t))

(defmethod docstring ((writer generic-writer-definition))
  "Return generic WRITER's docstring."
  (documentation `(setf ,(definition-symbol writer)) 'function))

;; #### PORTME.
(defmethod docstring ((slot slot-definition))
  "Return SLOT's docstring."
  (sb-pcl::%slot-definition-documentation (slot-definition-slot slot)))

(defmethod docstring ((combination combination-definition))
  "Return method COMBINATION's docstring."
  (documentation (definition-symbol combination) 'method-combination))

(defmethod docstring ((classoid classoid-definition))
  "Return CLASSOID's docstring."
  (documentation (definition-symbol classoid) 'type))

(defmethod docstring ((type type-definition))
  "Return TYPE's docstring."
  (documentation (definition-symbol type) 'type))


;; ------------------
;; Type name protocol
;; ------------------

(defmethod type-name ((constant constant-definition))
  "Return \"constant\""
  "constant")

(defmethod type-name ((special special-definition))
  "Return \"special variable\""
  "special variable")

(defmethod type-name ((symbol-macro symbol-macro-definition))
  "Return \"symbol macro\""
  "symbol macro")

(defmethod type-name ((macro macro-definition))
  "Return \"macro\""
  "macro")

(defmethod type-name ((compiler-macro compiler-macro-definition))
  "Return \"compiler macro\""
  "compiler macro")

(defmethod type-name ((function function-definition))
  "Return \"function\""
  "function")

(defmethod type-name ((generic generic-definition))
  "Return \"generic function\""
  "generic function")

(defmethod type-name ((method method-definition))
  "Return \"method\""
  "method")

;; #### NOTE: no TYPE-NAME method for SLOT-DEFINITION

(defmethod type-name ((combination short-combination-definition))
  "Return \"short method combination\"."
  "short method combination")

(defmethod type-name ((combination long-combination-definition))
  "Return \"long method combination\"."
  "long method combination")

(defmethod type-name ((condition condition-definition))
  "Return \"condition\""
  "condition")

(defmethod type-name ((structure structure-definition))
  "Return \"structure\""
  "structure")

(defmethod type-name ((class class-definition))
  "Return \"class\""
  "class")

(defmethod type-name ((type type-definition))
  "Return \"type\""
  "type")


;;; symbol.lisp ends here
