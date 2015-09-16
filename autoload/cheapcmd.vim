if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
let s:WILDLIST_MAX_HEIGHT = 19
let s:LEADBGN_PAT = '^\s*[,;]*\%(\%(\d\+\|[.$%]\|/.\{-}/\|?.\{-}?\|\\[/?&]\|''[''`"^.<>()[\]{}[:alnum:]]\)\s*\%([+-]\d*\s*\)\?[,;]*\s*\)*\zs\a\w\+$'
function! s:get_cands(lead) "{{{
  let cmds = map(__cheapcmd#lim#misc#get_cmdresults(':command')[1:], 'matchstr(v:val, ''\u\w*'')')
  let pat = '\C^'. substitute(toupper(a:lead), '.', '\0\\l*', 'g')
  return filter(cmds[:], 'v:val =~ pat') + sort(filter(cmds + s:bcmds, 'v:val =~ "^". a:lead'))
endfunction
"}}}
let s:dir = expand('<sfile>:p:h:h'). '/cheapcmd'
function! s:get_basiccmds() "{{{
  if exists('s:bcmds')
    return s:bcmds
  end
  let path = s:dir. '/basiccmds'
  return filereadable(path) ? filter(readfile(path), 'exists(":".v:val)') : []
endfunction
"}}}

"Exclusive:
function! s:regular_expand() "{{{
  cnoremap <Plug>(cheapcmd:tab)  <Tab>
  cnoremap <expr><Plug>(cheapcmd:rest-wcm)   cheapcmd#_rest_wcm()
  let s:save_wcm = &wcm
  set wcm=<Tab>
  call feedkeys("\<Plug>(cheapcmd:tab)\<Plug>(cheapcmd:rest-wcm)", 'm')
endfunction
"}}}
function! cheapcmd#_rest_wcm() "{{{
  cunmap <Plug>(cheapcmd:tab)
  cunmap <Plug>(cheapcmd:rest-wcm)
  let &wcm = s:save_wcm
  unlet s:save_wcm
  let s:save_regularexpand_context = [getcmdline(), getcmdpos()]
  return ''
endfunction
"}}}
function! s:make_wildmenu_cands(cands) "{{{
  let candslast = len(a:cands)-1
  let ret = []
  let i = 0
  let j = 0
  while j <= candslast
    call add(ret, i==0 ? [''] : [])
    let width = i==0 ? 0 : 2
    while j <= candslast
      let width += strwidth(a:cands[j]) + 2
      if !(ret[i]==[] || (j>=candslast ? width-2 : width) < &co)
        break
      end
      call add(ret[i], a:cands[j])
      let j += 1
    endwhile
    let i += 1
  endwhile
  return ret
endfunction
"}}}
function! s:get_cheapcmd_cmodeexpand_mapping() "{{{
  let save_vfile = &verbosefile
  set verbosefile=
  redir => result
  silent! cmap
  redir END
  let &verbosefile = save_vfile
  return __cheapcmd#lim#misc#expand_keycodes(matchstr(result, '\%(\n\|^\)\S\s\+\zs\S\+\ze\s\+\%(\*\s\)\?<Plug>(cheapcmd-expand)\%(\n\|$\)'))
endfunction
"}}}
function! s:get_wildlist(cands, cmdline) "{{{
  let lanewidth = 0
  for cand in a:cands
    let w = strwidth(cand)
    let lanewidth = w > lanewidth ? w : lanewidth
  endfor
  let lanewidth += 2
  let lane = &co / lanewidth
  let len = len(a:cands)
  let height = len / lane
  if len % lane
    let height += 1
  end
  if height > s:WILDLIST_MAX_HEIGHT
    let height = s:WILDLIST_MAX_HEIGHT
  end
  let fmt = repeat('%-'. lanewidth . 's', lane)
  let eachmax = height * (lane-1)
  let row = 0
  let str = ':'. a:cmdline. "\n"
  while row < height
    let str .= call('printf', [fmt] + map(range(row, row + eachmax, height), 'get(a:cands, v:val, "")')). "\n"
    let row += 1
  endwhile
  return [str, height]
endfunction
"}}}
function! cheapcmd#_showlist() "{{{
  cunmap <Plug>(cheapcmd:showlist)
  let s:save_cmdheight = exists('s:save_cmdheight') ? s:save_cmdheight : &l:cmdheight
  let s:save_updatetime = exists('s:save_updatetime') ? s:save_updatetime : &updatetime
  call s:wmd.showlist()
  set updatetime=1
  aug cheapcmd-on_leave_cmdline
    autocmd!
    autocmd CursorHold  * call cheapcmd#_rest_cmdheight()
    autocmd CursorHoldI * call cheapcmd#_rest_cmdheight()
  aug END
  return ''
endfunction
"}}}
function! cheapcmd#_rest_cmdheight() "{{{
  let &l:cmdheight = s:save_cmdheight
  let &updatetime = s:save_updatetime
  unlet! s:save_cmdheight s:save_updatetime s:wmd s:save_regularexpand_context
  autocmd! cheapcmd-on_leave_cmdline
endfunction
"}}}

let s:WildMode = {}
function! s:newWildMode(leadbgn, cmdline, cmdpos) "{{{
  let obj = copy(s:WildMode)
  let obj._line = a:cmdline
  let obj._pos = a:cmdpos
  let obj.leadbgn = a:leadbgn
  let obj.lead = a:cmdline[a:leadbgn : a:cmdpos-2]
  let obj.leadlen = len(obj.lead)
  let obj.cands = s:get_cands(obj.lead)
  let obj._candslen = len(obj.cands)
  let obj.cmplstart = 0
  let obj.modes = split(&wildmode, ',')
  let obj._modelen = len(obj.modes)
  let obj.i = -1
  let obj._wildlist = []
  let obj._is_finished = 0
  return obj
endfunction
"}}}
function! s:WildMode.is_succeeded(cmdline, cmdpos) "{{{
  return !self._is_finished && self.i+1 < self._modelen && self._line ==# a:cmdline && self._pos == a:cmdpos
endfunction
"}}}
function! s:WildMode.update_lead(leadbgn, cmdpos) "{{{
  let self.leadbgn = a:leadbgn
  let self.lead = self._line[a:leadbgn : a:cmdpos-2]
  let self.leadlen = len(self.lead)
endfunction
"}}}
function! s:WildMode.showlist() "{{{
  let &l:cmdheight = self._wildlist[1] + 1
  redraw
  echo self._wildlist[0]. ":". getcmdline()
  let &l:cmdheight = 1
  call feedkeys(" \<BS>", 'n')
endfunction
"}}}
function! s:WildMode.fire() "{{{
  if self.modes==[] || self._candslen < 2
    let self._is_finished = 1
    return self.cands==[] ? '' : repeat("\<BS>", self.leadlen). self.cands[0]
  end
  let self.i += 1
  if self.modes[self.i] =~# 'longest'
    let ret = self._fill_longest()
  else
    let ret = self.lead
  end
  if self._wildlist==[] && self.modes[self.i] =~# 'list'
    let self._wildlist = s:get_wildlist(self.cands, self._line)
  end
  if self.modes[self.i] =~# 'full'
    let self._is_finished = 1
    let wildmenu = s:newWildMenu(self.cands, self.lead, self._get_left(), self._line[self._pos-1 :], self._wildlist)
    try
      let [ret, surplus] = wildmenu.start()
    catch /E523:/
      return repeat("\<BS>", self.leadlen). wildmenu.get_crrstr()
    finally
      call wildmenu.finalize()
    endtry
    if surplus!=''
      call feedkeys(substitute(surplus, "\<Esc>", "\<C-c>", "g"), 'm')
    end
  end
  if self._wildlist!=[]
    cnoremap <expr><Plug>(cheapcmd:showlist)   cheapcmd#_showlist()
    call feedkeys("\<Plug>(cheapcmd:showlist)", 'm')
  end
  return repeat("\<BS>", self.leadlen). ret
endfunction
"}}}
function! s:WildMode._get_left() "{{{
  return self.leadbgn==0 ? '' : self._line[: self.leadbgn-1]
endfunction
"}}}

function! s:WildMode._fill_longest() "{{{
  let i = 0
  while self.cands[0][i] ==# self.cands[1][i]
    let i += 1
  endwhile
  if i==0
    return self.lead
  end
  let longest = self.cands[0][: i-1]
  let j = 2
  while j < self._candslen && longest!=''
    let longest = matchstr(self.cands[j], '^\V\%['. escape(longest, '\'). ']')
    let j += 1
  endwhile
  let len = len(longest)
  if len < self.leadlen
    return self.lead
  end
  let self._line = self._get_left(). longest. self._line[self._pos-1 :]
  let self._pos = self.leadbgn + len + 1
  return longest
endfunction
"}}}

let s:WildMenu = {}
function! s:newWildMenu(cands, lead, left, right, wildlist) "{{{
  let obj = copy(s:WildMenu)
  let obj.lead = a:lead
  let obj._left = a:left
  let obj._right = a:right
  let obj._wildlist = a:wildlist
  let obj._save_more = &more
  let obj.wcands = s:make_wildmenu_cands(a:cands)
  let obj._wcandslast = len(obj.wcands)-1
  let obj._save_lastwinnr = winnr('$')
  let obj._save_stl = getwinvar(obj._save_lastwinnr, '&stl')
  let obj._save_wnr = winnr()
  let obj._save_cmdheight = &l:cmdheight
  let obj._save_guicursor = &gcr
  let obj._save_t_ve = &t_ve
  let obj.i = 0
  let obj.j = 1
  return obj
endfunction
"}}}
function! s:WildMenu.start() abort "{{{
  if self._wildlist!=[]
    set nomore
    let &l:cmdheight = self._wildlist[1] + 1
  end
  if self._right!=''
    setl gcr=a:block-blinkon0-NONE t_ve=
  end
  let def = {"\<Left>": '_prev', "\<C-p>": '_prev', "\<S-Tab>": '_prev', "\<Right>": '_next', "\<C-n>": '_next'}
  let def[nr2char(&wc)] = '_next'
  let mapping = s:get_cheapcmd_cmodeexpand_mapping()
  if mapping!=''
    let def[mapping] = '_next'
  end
  call self._draw()
  while 1
    let input = __cheapcmd#lim#cap#keymappings(def, {'transit': 1})
    if !(v:version>704 || v:version==704 && has('patch870')) && get(input, 'surplus', '')[0]=="\x80" && input.surplus[1]=="\xfc"
      continue
    end
    if input=={} || !has_key(self, input.action)
      return [self.get_crrstr(), get(input, 'surplus', '')]
    end
    call self[input.action]()
    call self._draw()
  endwhile
endfunction
"}}}
function! s:WildMenu.get_crrstr() "{{{
  return self.wcands[self.i][self.j]=='' ? self.lead : self.wcands[self.i][self.j]
endfunction
"}}}
function! s:WildMenu.finalize() "{{{
  call setwinvar(self._save_lastwinnr, '&stl', self._save_stl)
  let &l:cmdheight = self._save_cmdheight
  let &l:gcr = self._save_guicursor
  let &l:t_ve = self._save_t_ve
  redraw!
  let &more = self._save_more
  redraw
endfunction
"}}}

function! s:WildMenu._draw() "{{{
  let cands = self.wcands[self.i]
  let stl = '%#StatusLine#'
  if self.i > 0
    let stl .= '< '
    if self.j > 0
      let stl .= join(cands[: self.j-1], '  '). '  '
    end
    let stl .= '%#WildMenu#'. cands[self.j]. '%#StatusLine#'
    if self.j < len(cands)-1
      let stl .= '  '. join(cands[self.j+1 :], '  ')
    end
  else
    let stl .= join(cands[1 : self.j-1], '  ')
    if self.j > 0
      let stl .= (self.j==1 ? '' : '  '). '%#WildMenu#'. cands[self.j]. '%#StatusLine#'
      if self.j < len(cands)-1
        let stl .= '  '. join(cands[self.j+1 :], '  ')
      end
    end
  end
  if self.i != self._wcandslast
    let stl .= ' >'
  end
  call setwinvar(self._save_lastwinnr, '&stl', stl)
  redraw
  echo get(self._wildlist, 0, ''). ":". self._left. self.get_crrstr()
  if self._right==''
    return
  end
  echoh Cursor
  echon self._right[0]
  echoh NONE
  echon self._right[1:]
endfunction
"}}}
function! s:WildMenu._prev() "{{{
  if self.j > 0
    let self.j -= 1
  elseif self.i > 0
    let self.i -= 1
    let self.j = len(self.wcands[self.i])-1
  else
    let self.i = self._wcandslast
    let self.j = len(self.wcands[self.i])-1
  end
endfunction
"}}}
function! s:WildMenu._next() "{{{
  if self.j < len(self.wcands[self.i])-1
    let self.j += 1
  elseif self.i < self._wcandslast
    let self.i += 1
    let self.j = 0
  else
    let self.i = 0
    let self.j = 0
  end
endfunction
"}}}


"======================================
"Main:
function! cheapcmd#expand() "{{{
  let cmdline = getcmdline()
  let cmdpos = getcmdpos()
  let leadbgn = match(cmdline[: cmdpos-2], s:LEADBGN_PAT)
  if exists('s:wmd') && s:wmd.is_succeeded(cmdline, cmdpos)
    call s:wmd.update_lead(leadbgn, cmdpos)
    return s:wmd.fire()
  else
    unlet! s:wmd
  end
  if (exists('s:save_regularexpand_context') && s:save_regularexpand_context ==# [cmdline, cmdpos]) || leadbgn == -1 || getcmdtype() != ':'
    call s:regular_expand()
    return ''
  end
  unlet! s:save_regularexpand_context
  let s:bcmds = s:get_basiccmds()
  let s:wmd = s:newWildMode(leadbgn, cmdline, cmdpos)
  return s:wmd.fire()
endfunction
"}}}

function! cheapcmd#cmdwin_cmpl() "{{{
  if bufname('%') !=# '[Command Line]'
    return "\<Tab>"
  elseif pumvisible()
    return "\<C-n>"
  end
  let line = getline('.')
  let lead = matchstr(line[: col('.')-2], s:LEADBGN_PAT)
  if lead == ''
    return "\<C-x>\<C-v>"
  end
  let s:bcmds = s:get_basiccmds()
  let s:_save_omnifunc = &omnifunc
  setl omnifunc=cheapcmd#_cmdwin_cmpl
  return "\<C-x>\<C-o>"
endfunction
"}}}
function! cheapcmd#_cmdwin_cmpl(findstart, base) "{{{
  if a:findstart
    return !exists('s:_save_omnifunc') ? -1 : match(getline('.')[: col('.')-2], s:LEADBGN_PAT)
  end
  let &l:omnifunc = s:_save_omnifunc
  unlet s:_save_omnifunc
  return s:get_cands(a:base)
endfunction
"}}}

"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
