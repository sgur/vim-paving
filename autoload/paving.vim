let s:save_cpo = &cpo
set cpo&vim



let g:paving#hardcode = get(g:, 'paving#hardcode', 0)



function! paving#store(filename, bundle_dir, ...)
  let lines = []
  " bundle directory
  let bundles = s:glob_bundles(a:bundle_dir)
  let loaded = s:register(bundles)
  let [bundles, nobundles] = s:prune_bundles(bundles)
  call add(lines, 'set runtimepath =' . s:rtp_generate(bundles))
  call extend(lines, s:source_functions(nobundles))
  call add(lines, 'let s:loaded = ' . string(loaded))
  " ftbundle directory
  if a:0 > 0
    call extend(lines, s:ft_generate(expand(a:1)))
    call extend(lines, s:deploy_functions())
  endif
  call writefile(lines, expand(a:filename))
endfunction



function! paving#cmd_generate(...)
  let config = {}

  let path = s:default_vimdir()

  for opt in a:000
    if stridx(opt, '-bundle') == 0
      let opts = split(opt, '=')
      let config.bundle = len(opts) > 1 ? split(opts[1],',') : path . '/bundle'
    elseif stridx(opt, '-ftbundle') == 0
      let opts = split(opt, '=')
      let config.ftbundle = len(opts) > 1 ? opts[1] : path . '/ftbundle'
    else
      let config.vimrc = opt
    endif
  endfor

  if !has_key(config, 'vimrc')
    let config.vimrc = get(config, 'vimrc', path . '/' . get(g:, 'rtp_default_filename', 'vimrc.loader'))
  endif
  if !has_key(config, 'bundle')
    let config.bundle = get(config, 'bundle', path . '/bundle')
  endif

  if has_key(config, 'ftbundle')
    call paving#store(config.vimrc, config.bundle, config.ftbundle)
  else
    call paving#store(config.vimrc, config.bundle)
  endif
endfunction
let s:loaded = {}
let s:bufname = expand('<sfile>')



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
    let base_dir = join(map(a:base_dir, 'fnamemodify(v:val, ":p")'), ',')
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
    for ft in split(fnamemodify(dir, ':t'), ',')
      let bundles = s:glob_bundles(dir)
      for bundle in bundles
        for ftdetect in glob(bundle . '/ftdetect/*.vim', 1, 1)
          if g:paving#hardcode
            call add(lines, '" ' . ftdetect)
            call extend(lines, filter(readfile(ftdetect), 'v:val !~# "^$" && v:val !~# "^\s*\""'))
          else
            call add(lines, 'source ' . ftdetect)
          endif
        endfor
      endfor
      let _[ft] = get(_, ft, []) + bundles
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


function! s:deploy_functions()
  let buf = readfile(s:bufname)
  let start = index(buf, '" BEGIN')
  let end = index(buf, '" END', start)
  for l in range(start, end)
    let buf[l] = substitute(buf[l]
          \ , 's:GLOBPATH(\([^)]\+\))'
          \ , !has('patch-7.4.279')
          \   ? 'globpath(\1, 1, 1)'
          \   : 'split(globpath(\1, 1))'
          \ ,'g')
  endfor
  return buf[start+1 : end-1]
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

" BEGIN
function! PavingLoaded(plugin)
  return has_key(s:loaded, a:plugin)
endfunction

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
" END

let &cpo = s:save_cpo
unlet s:save_cpo


if expand("%:p") != expand("<sfile>:p")
  finish
endif


call paving#store(g:env#rc_dir . '/vimrc.loader', map(['bundle', 'local'], 'g:env#rc_dir . "/" . v:val') , g:env#rc_dir . '/ftbundle')