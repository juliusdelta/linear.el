;;; linear.el --- An Interface for Linear Project Management -*- lexical-binding: t; -*-

;; Copyright (C) 2024  JD Gonzales

;; Author: JD Gonzales <jd_gonzales@icloud.com>
;; URL: https://github.com/juliusdelta/linear.el
;; Version: 0.0.1
;; Package-Requires: ((emacs "29.0"))
;; Keywords: tools, convenience

;; This file is not part of GNU Emacs

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; For a full copy of the GNU General Public License
;; see <https://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; This is a package that allows you to interact with Linear App Project Management via a Magit style interface

;; Example Magit Section Use
;;

;; (magit-insert-section (magit-section "Section2")
;;   (magit-insert-heading (insert "Heading2"))
;;   (magit-insert-section-body (insert "Body2\n\n")))

;; (magit-insert-section (magit-section "Section3")
;;   (magit-insert-heading (insert "Heading3"))

;;   ;; can nest section inside other sections
;;   (magit-insert-section (magit-section "Section3a")
;;     (magit-insert-heading (insert "Heading3a"))
;;     (magit-insert-section-body (insert "Body3a\n\n")))

;;   (magit-insert-section (magit-section "Section3b")
;;     (magit-insert-heading (insert "Heading3b"))
;;     (magit-insert-section-body (insert "Body3b\n\n"))))

;;; Code:
(require 'plz)
(require 'eieio)
(require 'graphql)

;;;; Utility
(defun linear--linear-request (gql-query)
  "Pass in a GQL Query to recieve from Linear"
  (alist-get 'data (plz 'post "https://api.linear.app/graphql"
                     :headers `(("Content-Type" . "application/json") ("Authorization" . ,(getenv "LINEAR_API_KEY")))
                     :body (json-encode `(("query" . ,gql-query)))
                     :as #'json-read)))
;;;; Private
(defun linear--projects-data ()
  "Fetch Project data"
  (alist-get 'nodes
             (alist-get
              'projects
              (linear--linear-request
               (graphql-query
                ((projects
                  :arguments ((includeArchived . false))
                  (nodes state progress name (issues (nodes id identifier title url description)) (teams (nodes name))))))))))

(defun linear--me-data ()
  "Me data"
  (alist-get 'viewer
             (linear--linear-request (graphql-query ((viewer id name email (teams (nodes name))))))))

;;;; Private - UI
(defun linear--create-project-sections (proj)
  "Create project magit-sections"
  (let ((proj-name (alist-get 'name proj))
        (issues-list (alist-get 'nodes (alist-get 'issues proj)))
        (state (alist-get 'state proj)))
    (magit-insert-section (magit-section 'project)
      (magit-insert-heading (insert (propertize proj-name 'face 'bold)))
      (magit-insert-section-body (insert (concat "State: " state "\n\n")))
      (linear--create-project-section-issues issues-list))))

(defun linear--create-project-section-issues (issues-list)
  "Create individual issue sections of issues section in project section"
  (cl-loop for issue across issues-list do
           (let ((issue-title (alist-get 'title issue))
                 (issue-ident (alist-get 'identifier issue))
                 (issue-description (alist-get 'description issue)))
             (magit-insert-section (magit-section 'issue-title)
               (magit-insert-heading (insert (format "[%s] - %s" issue-ident issue-title)))
               (magit-insert-section-body (insert (concat issue-description "\n\n")))))))

;; Public
(defun linear-status ()
  (interactive)
  (with-current-buffer (get-buffer-create "*magit-test-section*")
    (magit-section-mode)
    (let ((inhibit-read-only t))
      (erase-buffer)

      (insert (propertize "All Projects\n\n" 'face 'bold-italic))
      (cl-loop for proj across (linear--projects-data) do (linear--create-project-sections proj)))
    (pop-to-buffer (current-buffer))))
;;; linear.el ends here
