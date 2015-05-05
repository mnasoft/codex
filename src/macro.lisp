(defpackage codex.macro
  (:use :cl)
  (:import-from :common-doc
                :content-node
                :text-node
                :code
                :list-item
                :unordered-list
                ;; Operators
                :define-node
                :children
                :text)
  (:import-from :common-doc.macro
                :macro-node
                :expand-macro)
  (:import-from :common-doc.util
                :make-text
                :make-meta)
  (:export :*index*
           :cl-doc
           :with-package
           :param)
  (:documentation "CommonDoc macros for Codex."))
(in-package :codex.macro)

;;; Variables

(defvar *index* nil
  "The current Docparser index.")

(defvar *current-package-name* nil
  "The name of the current package. Set by the with-package macro.")

;;; Macro classes

(define-node cl-doc (macro-node)
  ()
  (:tag-name "cl:doc")
  (:documentation "Insert documentation of a node."))

(define-node with-package (macro-node)
  ((name :reader package-macro-name
         :type string
         :attribute-name "name"
         :documentation "The package's name."))
  (:tag-name "cl:with-package")
  (:documentation "Set the current package to use in the body."))

(define-node param (macro-node)
  ()
  (:tag-name "cl:param")
  (:documentation "An argument of an operator."))

;;; Utilities

(defun make-class-metadata (class)
  "Create metadata for HTML classes."
  (make-meta
   (list
    (cons "class" (if (listp class)
                      (format nil "~{codex-~A~#[~:; ~]~}" class)
                      (concatenate 'string
                                   "codex-"
                                   class))))))

(defmethod name-node (node)
  "Create a node representing the name of a node."
  (make-instance 'code
                 :metadata (make-class-metadata "name")
                 :children (list
                            (make-text
                             (docparser:render-humanize
                              (docparser:node-name node))))))

(defun docstring-node (node)
  "Create a node representing a node's docstring."
  (make-instance 'content-node
                 :metadata (make-class-metadata "docstring")
                 :children (children
                            (codex.markup:parse-string
                             (docparser:node-docstring node)))))

(defun list-to-code-node (class list)
  (make-instance 'code
                 :metadata (make-class-metadata class)
                 :children (list
                            (make-text
                             (with-standard-io-syntax
                               (let ((*print-case* :downcase))
                                 (princ-to-string list)))))))

(defun make-doc-node (class &rest children)
  (make-instance 'content-node
                 :metadata (make-class-metadata (list "doc-node" class))
                 :children children))

;;; Docparser nodes to CommonDoc nodes

(defgeneric expand-node (node)
  (:documentation "Turn a Docparser node into a CommonDoc one."))

(defun expand-operator-node (node class-name)
  "Expand a generic operator node. Called by more specific methods."
  (make-doc-node class-name
                 (name-node node)
                 (list-to-code-node "lambda-list"
                                    (docparser:operator-lambda-list node))
                 (docstring-node node)))

(defmethod expand-node ((node docparser:function-node))
  "Expand a function node."
  (expand-operator-node node "function"))

(defmethod expand-node ((node docparser:macro-node))
  "Expand a macro node."
  (expand-operator-node node "macro"))

(defmethod expand-node ((node docparser:generic-function-node))
  "Expand a generic function node."
  (expand-operator-node node "generic-function"))

(defmethod expand-node ((node docparser:method-node))
  "Expand a method node."
  (expand-operator-node node "method"))

(defmethod expand-node ((node docparser:operator-node))
  "Backup method when someone has created a subclass of operator-node that's not
explicitly supported by this method."
  (expand-operator-node node "operator"))

(defmethod expand-node ((node docparser:struct-slot-node))
  "Expand a structure slot node. This doesn't have any docstrings."
  (make-instance 'list-item
                 :metadata (make-class-metadata "slot")
                 :children
                 (list
                  (name-node node))))

(defmethod expand-node ((node docparser:class-slot-node))
  "Expand a class slot node."
  (make-instance 'list-item
                 :metadata (make-class-metadata "slot")
                 :children
                 (list
                  (name-node node)
                  (docstring-node node))))

(defmethod expand-node ((node docparser:struct-node))
  "Expand a structure definition node."
  (make-doc-node "struct"
                 (name-node node)
                 (docstring-node node)
                 (make-instance 'unordered-list
                                :metadata (make-class-metadata "slot-list")
                                :children
                                (loop for slot in (docparser:record-slots node)
                                  collecting (expand-node slot)))))

(defmethod expand-node ((node docparser:class-node))
  "Expand a class definition node."
  (make-doc-node "class"
                 (name-node node)
                 (docstring-node node)
                 (make-instance 'unordered-list
                                :metadata (make-class-metadata "slot-list")
                                :children
                                (loop for slot in (docparser:record-slots node)
                                  collecting (expand-node slot)))))

(defmethod expand-node ((node docparser:variable-node))
  "Expand a variable node."
  (make-doc-node "variable"
                 (name-node node)
                 (docstring-node node)))

(defmethod expand-node ((node docparser:type-node))
  "Expand a type node."
  (make-doc-node "type"
                 (name-node node)
                 (list-to-code-node "type-def"
                                    (docparser:operator-lambda-list node))
                 (docstring-node node)))

(defmethod expand-node ((node t))
  "When expanding an unsupported node, rather than generate an error, simply
create an error message."
  (make-text (format nil "Unsupported node type ~A." (type-of node))
             (make-class-metadata (list "error" "unsupported-node-error"))))

;;; Macroexpansions

(defparameter +type-name-to-class-map+
  (list (cons "function"  'docparser:function-node)
        (cons "macro"     'docparser:macro-node)
        (cons "generic"   'docparser:generic-function-node)
        (cons "method"    'docparser:method-node)
        (cons "variable"  'docparser:variable-node)
        (cons "struct"    'docparser:struct-node)
        (cons "class"     'docparser:class-node)
        (cons "type"      'docparser:type-node)
        (cons "cfunction" 'docparser:cffi-function)
        (cons "ctype"     'docparser:cffi-type)
        (cons "cstruct"   'docparser:cffi-struct)
        (cons "cunion"    'docparser:cffi-union)
        (cons "cenum"     'docparser:cffi-enum)
        (cons "cbitfield" 'docparser:cffi-bitfield))
  "Associate the string names of Docparser classes to the corresponding
docparser class names.")

(defun find-node-type-by-name (name)
  (rest (assoc name +type-name-to-class-map+ :test #'equal)))

(defun node-not-found (symbol)
  (make-instance 'content-node
                 :metadata (make-class-metadata (list "error" "no-node"))
                 :children
                 (list
                  (make-text "No node with name ")
                  (make-instance 'code
                                 :children
                                 (list
                                  (make-text (string-downcase symbol))))
                  (make-text "."))))

(defun no-such-type (name)
  (make-instance 'content-node
                 :metadata (make-class-metadata (list "error" "no-type"))
                 :children
                 (list
                  (make-text "No node type with name ")
                  (make-instance 'code
                                 :children
                                 (list (make-text name)))
                  (make-text "."))))

(defun find-node (type symbol rest)
  (let ((class (find-node-type-by-name type)))
    (if class
        (let ((nodes (docparser:query *index*
                                      :package-name *current-package-name*
                                      :symbol-name (string-upcase symbol)
                                      :class class)))
          (if (> (length nodes) 0)
              (expand-node (elt nodes 0))
              ;; No node with that name, report an error
              (node-not-found symbol)))
        (no-such-type type))))

(defmethod expand-macro ((node cl-doc))
  (let ((text-node (elt (children node) 0)))
    (assert (typep text-node 'text-node))
    (let* ((arguments (split-sequence:split-sequence #\Space (text text-node))))
      (destructuring-bind (type symbol &rest rest)
          arguments
        (format t "Inserting documentation for ~A ~S.~%" type symbol)
        (find-node type symbol rest)))))

(defmethod expand-macro ((node with-package))
  (let* ((package-name (package-macro-name node))
         (*current-package-name* (string-upcase package-name))
         (new-node (make-instance 'content-node
                                  :children (children node))))
    ;; Expand inner macros
    (common-doc.macro:expand-macros new-node)
    new-node))

(defmethod expand-macro ((node param))
  (make-instance 'code
                 :metadata (make-class-metadata "param")
                 :children (children node)))
