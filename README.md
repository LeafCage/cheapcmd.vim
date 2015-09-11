cheapcmd.vim
============

Introduction
------------

*cheapcmd.vim* enable command-line-completion to expand short keyword of user-defined commands.

e.g.)
- `vhg`  -> `VimHelpGenerator`, `VimHelpGeneratorVirtual`
- `vhgv` -> `VimHelpGeneratorVirtual`
- `qr`   -> `QuickRun`
- `cp`   -> `CtrlP`, `CtrlPBuffer`, `CtrlPClearAllCaches`, ... `cpfile`, `cprevious`
- `cpb`  -> `CtrlPBuffer`


Usage
-----

```vim
"for cmdline
cmap <Tab> <Plug>(cheapcmd-expand)

"for cmdwin
aug cheapcmd-cmdwin
  autocmd!
  autocmd CmdwinEnter * call s:define_cmdwin_mappings()
aug END
function! s:define_cmdwin_mappings()
  nmap <buffer><Tab> <Plug>(cheapcmd-expand)
  imap <buffer><Tab> <Plug>(cheapcmd-expand)
endfunction
```

Type `<Tab>` after short keyword of user-defined commands in command line head.
