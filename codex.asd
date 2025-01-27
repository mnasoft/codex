(defsystem codex
  :author "Fernando Borretti <eudoxiahp@gmail.com>"
  :maintainer "Fernando Borretti <eudoxiahp@gmail.com>"
  :license "MIT"
  :version "0.2"
  :homepage "https://github.com/CommonDoc/codex"
  :bug-tracker "https://github.com/CommonDoc/codex/issues"
  :source-control (:git "git@github.com:CommonDoc/codex.git")
  :depends-on (:docparser
               :docparser/corrector
               :common-doc
               :common-doc-contrib
               :pandocl
               :codex-templates
               :cl-slug
               :cl-ppcre
               :alexandria)
  :components ((:module "src"
                :serial t
                :components
                ((:file "error")
                 (:file "markup")
                 (:file "manifest")
                 (:file "macro")
                 (:file "codex")
                 (:file "quickstart"))))
  :description "A documentation system for Common Lisp."
  :long-description
  #.(uiop:read-file-string
     (uiop:subpathname *load-pathname* "README.md"))
  :in-order-to ((test-op (test-op codex-test))))
