cheapcmd.vim
============

Introduction
------------

*cheapcmd.vim* expand short name of user-defined commands.

e.g.)
- `vhg`  -> `VimHelpGenerator`, `VimHelpGeneratorVirtual`
- `vhgv` -> `VimHelpGeneratorVirtual`
- `qr`   -> `QuickRun`
- `cp`   -> `CtrlP`, `CtrlPBuffer`, `CtrlPClearAllCaches`, `CtrlPClearCache`, ...
- `cpb`  -> `CtrlPBuffer`


Usage
-----

```vim
"for cmdline
cmap <Tab> <Plug>(cheapcmd-expand)

"for cmdwin
aug cheapcmd-settings
  sutocmd!
  autocmd CmdwinEnter * call s:define_cmdwin_mappings()
aug END
function! s:define_cmdwin_mappings()
  nmap <buffer><Tab> <Plug>(cheapcmd-expand)
  imap <buffer><Tab> <Plug>(cheapcmd-expand)
endfunction
```

