let s:save_cpo = &cpo
set cpo&vim



let g:paving#hardcode = 0
let g:paving#filetype_separator = '.'



function! paving#store(filename, bundle_dir, ...)
  let lines = []
  " bundle directory
  let bundles = s:glob_bundles(a:bundle_dir)
  let loaded = s:register(bundles)
  let [bundles, nobundles] = s:prune_bundles(bundles)
  call add(lines, 'set runtimepath =' . s:rtp_generate(bundles))
  call add(lines, 'let s:loaded = ' . string(loaded))
  call extend(lines, s:source_functions(nobundles))
  call extend(lines, s:deploy_loaded())
  " ftbundle directory
  if a:0 > 0
    call extend(lines, s:ft_generate(expand(a:1)))
    call extend(lines, s:deploy_on_source())
  endif
  call writefile(lines, expand(a:filename))
  return loaded
endfunction


function! paving#cmd_generate(...)
  let config = copy(get(g:, 'paving#config', s:default_params()))
  call extend(config , s:parse_params(a:000), 'force')

  let loaded = has_key(config, 'ftbundle')
        \ ? paving#store(config.vimrc, config.bundle, config.ftbundle)
        \ : paving#store(config.vimrc, config.bundle)

  call s:stats(config, loaded)
endfunction


let s:loaded = {}
let s:bufname = expand('<sfile>')


function! s:stats(config, loaded_plugins)
  echohl Title | echo 'filename:'
  echohl NONE | echo a:config.vimrc
  echohl Title | echo 'bundle dir(s):'
  echohl NONE | echo join(a:config.bundle, ', ')
  if has_key(a:config, 'ftbundle')
    echohl Title | echo 'ftbundle dir:'
    echohl NONE | echo a:config.ftbundle
  endif
  echohl Title | echo 'loaded plugins:'
  echohl NONE | echo join(sort(keys(a:loaded_plugins)), ', ')
endfunction


function! s:parse_params(args)
  let config = {}
  let path = s:default_vimdir()

  for opt in a:args
    if stridx(opt, '-bundle') == 0
      let opts = split(opt, '=')
      let config.bundle = len(opts) > 1 ? split(opts[1],',') : [path . '/bundle']
    elseif stridx(opt, '-ftbundle') == 0
      let opts = split(opt, '=')
      let config.ftbundle = len(opts) > 1 ? opts[1] : path . '/ftbundle'
    else
      if filereadable(opt)
        let config.vimrc = opt
      endif
    endif
  endfor

  return config
endfunction


function! s:default_params()
  return {
        \   'vimrc' : '~/.vimrc.paved'
        \ , 'bundle' : [s:default_vimdir() . '/bundle']
        \ }
endfunction


function! s:prepare_blacklist()
  let oldval = &wildignore
  let newval = '*~,' . join(map(copy(get(g:, 'paving#blacklist', [])), '"*" . v:val . "*"'), ',')
  return [oldval, newval]
endfunction


function! s:glob(expr)
  let [wig, &wildignore] = s:prepare_blacklist()
  try
    return glob(a:expr, 0, 1)
  finally
    let &wildignore = wig
  endtry
endfunction


function! s:globpath(path, expr)
  let [wig, &wildignore] = s:prepare_blacklist()
  try
    return has('patch-7.4.279')
          \ ? globpath(a:path, a:expr, 0, 1)
          \ : split(globpath(a:path, expr, 1))
  finally
    let &wildignore = wig
  endtry
endfunction


function! s:glob_bundles(base_dir)
  if type(a:base_dir) == type([])
    let base_dir = join(map(a:base_dir, 'fnamemodify(v:val, ":p:h")'), ',')
    let dirs = s:globpath(base_dir, '*')
  else
    let base_dir = fnamemodify(a:base_dir, ':p')
    let dirs = s:glob(base_dir . '*')
  endif
  return map(dirs, 'fnamemodify(v:val, ":~")')
endfunction


function! s:glob_after(rtp)
  return s:globpath(a:rtp, 'after')
endfunction


function! s:register(bundles)
  let _ = {}
  for bundle in a:bundles
    let _[fnamemodify(bundle, ':t')] = 1
  endfor
  return _
endfunction


function! s:rtp_generate(bundles)
  let bundle_rtp = join(a:bundles, ',')
  let after_rtp = join(s:glob_after(bundle_rtp), ',')
  let rtp = &runtimepath
  try
    set runtimepath&
    let rtps = split(&runtimepath, ',')
    return join([rtps[0], bundle_rtp, join(rtps[1:-2], ','), after_rtp, rtps[-1]], ',')
  finally
    let &runtimepath = rtp
  endtry
endfunction


function! s:ft_generate(ftbundle_dir)
  let _ = {}
  let lines = []
  for dir in s:glob(fnamemodify(a:ftbundle_dir, ':p') . '*')
    for ftdetect in glob(dir . '/*/ftdetect/*.vim', 1, 1)
      if g:paving#hardcode
        call add(lines, '" ' . ftdetect)
        call extend(lines, filter(readfile(ftdetect), 'v:val !~# "^$" && v:val !~# "^\s*\""'))
      else
        call add(lines, 'source ' . ftdetect)
      endif
    endfor
    let dirs = s:glob_bundles(dir)
    for ft in split(fnamemodify(dir, ':t'), '\V' . g:paving#filetype_separator)
      let _[ft] = get(_, ft, []) + dirs
    endfor
  endfor

  call add(lines, 'augroup ftbundle')
  for ft in keys(_)
    call add(lines,
          \   printf('  autocmd FileType %s  call s:on_source(%s)'
          \   , ft, string(_[ft])))
  endfor
  call add(lines, 'augroup END')
  return lines
endfunction


function! s:source_functions(dirnames)
  let _ = []
  for dir in a:dirnames
    let plugins = glob(dir . '/plugin/**/*.vim', 1, 1)
    for plugin in plugins
      if g:paving#hardcode
        call add(_, '" ' . plugin)
        let _ += filter(readfile(plugin), 'v:val !~# "^\s*\""')
      else
        let _ += map(plugins, '"source " . v:val')
      endif
    endfor
  endfor
  return _
endfunction


function! s:prune_bundles(dirnames)
  let [bundles, nobundles] = [[], []]
  for d in a:dirnames
    let dir = filter(glob(d . '/*', 1, 1), 'isdirectory(v:val)')
    if len(dir) == 1 && fnamemodify(dir[0], ':t') is 'plugin'
      call add(nobundles, d)
    else
      call add(bundles, d)
    endif
  endfor
  return [bundles, nobundles]
endfunction


function! s:get_function(id)
  let buf = readfile(s:bufname)
  let start = index(buf, '" BEGIN_' . a:id)
  let end = index(buf, '" END_' . a:id, start)
  return buf[start+1 : end-1]
endfunction


function! s:deploy_loaded()
  return s:get_function('LOADED')
endfunction


function! s:deploy_on_source()
  let buf = s:get_function('ON_SOURCE')
  for l in range(0, len(buf)-1)
    let buf[l] = substitute(buf[l]
          \ , 's:GLOBPATH(\([^)]\+\))'
          \ , !has('patch-7.4.279')
          \   ? 'globpath(\1, 1, 1)'
          \   : 'split(globpath(\1, 1))'
          \ ,'g')
  endfor
  return buf
endfunction


function! s:default_vimdir()
  let dirs = has('win32')
        \ ? ['~/vimfiles', '~/.vim']
        \ : ['~/.vim', '~/vimfiles']
  try
    return filter(map(dirs, 'expand(v:val)'), 'isdirectory(v:val)')[0]
  catch /^Vim\%((\a\+)\)\=:E15/
  catch /^Vim\%((\a\+)\)\=:E684/
    return '~/.vim'
  endtry
endfunction

" BEGIN_LOADED
let g:paving#enabled = 1

function! PavingLoaded(plugin)
  return has_key(s:loaded, a:plugin)
endfunction
" END_LOADED

" BEGIN_ON_SOURCE
function! s:on_source(bundle_dirs)
  for dir in a:bundle_dirs
    let key = fnamemodify(dir, ':t')
    if !has_key(s:loaded, key)
      let rtps = split(&runtimepath, ',')
      let bundled = insert(rtps, dir, 1)
      let after_dir = expand(dir . '/after')
      if isdirectory(after_dir)
        let bundled = insert(rtps, after_dir, -1)
      endif
      let &runtimepath = join(bundled, ',')
      let s:loaded[key] = 1
    endif
    for plugin in filter(s:GLOBPATH(dir, 'plugin/**/*.vim'), '!isdirectory(v:val)')
      execute 'source' fnameescape(plugin)
    endfor
  endfor
endfunction
" END_ON_SOURCE



if expand("%:p") != expand("<sfile>:p")
  let &cpo = s:save_cpo
  unlet s:save_cpo
  finish
endif


call paving#store('~/.vimrc.paved', map(['bundle', 'local'], 'g:env#rc_dir . "/" . v:val') , g:env#rc_dir . '/ftbundle')
