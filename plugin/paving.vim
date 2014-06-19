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

if !exists('g:paving#enabled')
  let &runtimepath .= ',' . expand('<sfile>:~:h:h')
endif


command! -nargs=* Pave  call paving#cmd_generate(<f-args>)



if !exists(':Helptags')
  command! -nargs=* -complete=dir Helptags  call paving#helptags(<f-args>)
endif


let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et:
