set backspace=indent,eol,start
set hidden
set ignorecase
set smartcase
set incsearch
set hlsearch
set number
set autoindent
set smarttab
set splitbelow
set splitright
set wildmenu

syntax on
filetype plugin indent on

if has('persistent_undo')
  let s:undo_dir = expand('~/.vim/undo//')
  if !isdirectory(s:undo_dir)
    call mkdir(s:undo_dir, 'p', 0700)
  endif
  let &undodir = s:undo_dir
  set undofile
endif

if has('clipboard')
  set clipboard=unnamedplus
endif
