" paving
" Version: 0.0.1
" Author: sgur <sgurrr+vim@gmail.com>
" License: MIT

if exists('g:loaded_paving')
  finish
endif
let g:loaded_paving = 1

let s:save_cpo = &cpo
set cpo&vim

command! -nargs=* PavingGenerate  call paving#cmd_generate(<f-args>)


let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et: