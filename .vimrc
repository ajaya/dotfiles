" ~/.vimrc - Minimal config for casual editing
" Plugins managed by vim-plug (:PlugUpdate to update)

" Basics
set nocompatible          " disable vi compat (fixes arrow keys on Linux)
set esckeys               " allow arrow keys in insert mode
set ttimeoutlen=50        " fast escape sequence detection (ms)
syntax on
set number                " line numbers
set cursorline            " highlight current line
set mouse=a               " mouse support in all modes
set clipboard=unnamed     " yank/paste uses system clipboard
set laststatus=2          " always show status bar
set showcmd               " show partial commands
set showmode              " show INSERT/VISUAL mode

" Indentation
set tabstop=2             " tab = 2 spaces
set shiftwidth=2          " indent = 2 spaces
set expandtab             " tabs -> spaces
set autoindent            " keep indent on new line

" Search
set incsearch             " search as you type
set hlsearch              " highlight matches
set ignorecase            " case-insensitive search
set smartcase             " ...unless uppercase used
set gdefault              " :s replaces all on line by default (no /g needed)

" Usability
set backspace=indent,eol,start  " backspace works everywhere
set scrolloff=5           " keep 5 lines above/below cursor
set wildmenu              " tab-complete commands
set wildmode=longest:full " complete to longest match first
set confirm               " ask to save instead of error

" Clear search highlight with Ctrl-L (also redraws screen)
nnoremap <C-l> :nohlsearch<CR><C-l>

" Status line
set statusline=%F%m%r\ %y\ %=\ L%l/%L\ C%c\ %p%%

" Remember cursor position on reopen
autocmd BufReadPost *
  \ if line("'\"") > 1 && line("'\"") <= line("$") |
  \   exe "normal! g`\"" |
  \ endif

" Treat dotfiles as shell scripts
autocmd BufNewFile,BufRead .bash*,.env* set filetype=sh
autocmd BufNewFile,BufRead *.properties set filetype=jproperties

" FZF runtime path (macOS homebrew arm64/x86_64, Linux)
if isdirectory('/opt/homebrew/opt/fzf')
  set rtp+=/opt/homebrew/opt/fzf
elseif isdirectory('/usr/local/opt/fzf')
  set rtp+=/usr/local/opt/fzf
elseif isdirectory('/usr/share/doc/fzf')
  set rtp+=/usr/share/doc/fzf
elseif isdirectory(expand('~/.fzf'))
  set rtp+=~/.fzf
endif

" ---- vim-plug (auto-install on first run) ----
let data_dir = '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

" AnsiEsc repo has a bad timezone in a git object — pre-clone with fsck disabled
if !isdirectory(expand('~/.vim/plugged/vim-plugin-AnsiEsc'))
  silent execute '!git -c transfer.fsckObjects=false -c fetch.fsckObjects=false'
    \ .' clone https://github.com/powerman/vim-plugin-AnsiEsc.git'
    \ .' ~/.vim/plugged/vim-plugin-AnsiEsc'
    \ .' && cd ~/.vim/plugged/vim-plugin-AnsiEsc'
    \ .' && git config transfer.fsckObjects false'
    \ .' && git config fetch.fsckObjects false'
endif

call plug#begin('~/.vim/plugged')

" ANSI color rendering (:AnsiEsc to toggle, auto on *.log)
Plug 'powerman/vim-plugin-AnsiEsc'

" Surround — change/add/delete quotes, tags, brackets
"   cs"'    change surrounding " to '
"   ds"     delete surrounding "
"   ysiw"   surround word with "
"   S"      surround selection (visual mode)
"   cst<p>  change surrounding tag to <p>
Plug 'tpope/vim-surround'

" Repeat — makes surround (and others) work with .
Plug 'tpope/vim-repeat'

" Commentary — toggle comments
"   gcc     toggle comment on line
"   gc      toggle comment on selection (visual)
"   gcap    toggle comment on paragraph
Plug 'tpope/vim-commentary'

" Visual star — select text then * to search for it
Plug 'nelstrom/vim-visual-star-search'

" Emmet — HTML/CSS shorthand expansion
"   div>ul>li*3  then Ctrl-y ,  expands to full HTML
"   Ctrl-y ,     expand abbreviation
"   Ctrl-y d     select tag pair
Plug 'mattn/emmet-vim'

call plug#end()

" Auto-render ANSI colors in log files (Rails, etc.)
autocmd BufReadPost *.log silent! AnsiEsc
