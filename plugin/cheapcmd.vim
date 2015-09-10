if expand('<sfile>:p')!=#expand('%:p') && exists('g:loaded_cheapcmd')| finish| endif| let g:loaded_cheapcmd = 1
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
cnoremap <expr><Plug>(cheapcmd-expand)    cheapcmd#expand()
nnoremap <expr><Plug>(cheapcmd-expand)    'a'. cheapcmd#cmdwin_cmpl()
inoremap <expr><Plug>(cheapcmd-expand)    cheapcmd#cmdwin_cmpl()

"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
