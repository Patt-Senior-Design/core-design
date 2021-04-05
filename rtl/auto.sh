#!/bin/sh
# -*- mode: emacs-lisp -*-
cd "$(dirname $0)"
exec emacs -Q --batch --eval="(progn $(tail -n+6 $0))" "$@"

(setq vc-follow-symlinks nil)
(require 'verilog-mode)
(dolist (path '("../src" "../src/bfs"))
  (push path verilog-library-directories))

(dolist (file command-line-args-left)
  (find-file (concat "build/" file))
  (insert-file-contents-literally (concat "../" file ".in") nil nil nil t)
  (verilog-auto)
  (save-buffer)
  (kill-buffer))
