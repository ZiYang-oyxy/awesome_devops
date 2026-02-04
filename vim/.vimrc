""""""""""""""""""""""""""""""""""""""""""""""""
" Maintainer:
"   Ouyang Xiongyi
"
"   Inspired by http://easwy.com/blog/
""""""""""""""""""""""""""""""""""""""""""""""""
set rtp+=~/.awesome_devops/vim

set nocompatible                " be iMproved
filetype off                    " required!

let mapleader = "\ "            " must on the top
let g:mapleader = "\ "

" update
"curl -fLo ~/.awesome_devops/vim/autoload/plug.vim --create-dirs \
"    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

if !executable('git')
  echo "Warning: Git is not installed. vim-"
endif
" 修改这个路径，能决定是否在ad中真正安装这些插件，供后续打包上传
silent! call plug#begin('~/.awesome_devops/vim/plugged')

"Plug 'yuttie/comfortable-motion.vim'
noremap <silent> <ScrollWheelDown> :call comfortable_motion#flick(40)<CR>
noremap <silent> <ScrollWheelUp>   :call comfortable_motion#flick(-40)<CR>

"###########################
"# main screen
"###########################
Plug 'majutsushi/tagbar'
map <silent> <F7> :TagbarToggle<CR>
set updatetime=500
let g:tagbar_left = 1
let g:tagbar_width = 50
let g:tagbar_compact = 1
let g:tagbar_iconchars = ['▸', '▾']
let g:tagbar_map_zoomwin = "z"
let g:tagbar_map_togglefold = "x"
let g:tagbar_map_jump = "o"
let g:tagbar_foldlevel = 0
let g:tagbar_sort = 0
" ctags可以自定义options，将.ctags拷贝到代码目录
"let g:tagbar_ctags_options = ['NONE', split(&rtp,",")[0].'/ctags.cnf']

Plug 'scrooloose/nerdtree', { 'on': ['NERDTreeToggle', 'NERDTreeFind'] }
map <silent> <F8> :NERDTreeToggle<CR>
map <silent> <Leader><F8> :NERDTreeFind<CR>
let NERDChristmasTree=1
let NERDTreeAutoCenter=1
let NERDTreeMouseMode=2
let NERDTreeShowBookmarks=1
let NERDTreeWinPos='right'
let NERDTreeWinSize=45
let NERDTreeShowLineNumbers=0
let NERDTreeIgnore=[
    \ '^cscope.out.in$', '^cscope.out$', '^cscope.files$', '^cscope.out.po$',
    \ '^tags$', '^.swp$', '^GPATH$', '^GRTAGS$', '^GTAGS$', 'tags.lock', 'tags.temp',
    \ '^gtags.conf$']
let NERDTreeMapToggleZoom='z'
let NERDTreeMinimalUI=1
Plug 'Xuyuanp/nerdtree-git-plugin', { 'on': 'NERDTreeToggle' }
let g:NERDTreeGitStatusIndicatorMapCustom = {
\ "Modified" : "*",
\ "Staged"   : "+",
\ "Untracked" : "u",
\ "Renamed" : "→",
\ "Unmerged" : "=",
\ "Deleted" : "х",
\ "Dirty" : "d",
\ "Clean" : "√",
\ "Ignored" : "I",
\ "Unknown" : "?"
\ }

"###########################
"# ctrlp
"###########################
Plug 'vim-scripts/L9'
Plug 'ctrlpvim/ctrlp.vim'
let g:ctrlp_cmd = 'CtrlPMRU'
let g:ctrlp_lazy_update = 1
let g:ctrlp_use_caching = 1
let g:ctrlp_clear_cache_on_exit = 0
let g:ctrlp_regexp = 1
let g:ctrlp_match_window = 'bottom,order:btt,min:1,max:20,results:100'
let g:ctrlp_max_files = 0
let g:ctrlp_working_path_mode = 'a'
let g:ctrlp_custom_ignore = {
\ 'dir':  '\v[\/]\.(git|hg|svn)$',
\ 'file': '\v\.(exe|so|dll)$',
\ }

let g:ctrlp_extensions = ['buffertag']

Plug 'ivalkeen/vim-ctrlp-tjump'
nnoremap <c-]> :CtrlPtjump<cr>
vnoremap <c-]> :CtrlPtjumpVisual<cr>
let g:ctrlp_tjump_skip_tag_name = 1
let g:ctrlp_tjump_only_silent = 1

Plug 'tacahiroy/ctrlp-funky'

"###########################
"# json tool
"###########################
Plug 'elzr/vim-json'
au! BufRead,BufNewFile *.json set filetype=json
augroup json_autocmd
  autocmd!
  autocmd FileType json set autoindent
  autocmd FileType json set formatoptions=tcq2l
  autocmd FileType json set textwidth=78 shiftwidth=2
  autocmd FileType json set softtabstop=2 tabstop=8
  autocmd FileType json set expandtab
  autocmd FileType json set foldmethod=syntax
augroup END
let g:vim_json_syntax_conceal = 0
filetype plugin indent on     " required!

"###########################
"# Markdown tool
"###########################
autocmd FileType markdown setlocal shiftwidth=4 tabstop=4 expandtab
"Plug 'vim-pandoc/vim-pandoc'
"Plug 'vim-pandoc/vim-pandoc-syntax'
"let g:pandoc#modules#disabled=["formatting", "spell", "bibliographies", "completion", "hypertext"]
"let g:pandoc#syntax#conceal#urls=1

Plug 'jszakmeister/markdown2ctags'
" Add support for markdown files in tagbar.
let g:tagbar_type_markdown = {
    \ 'ctagstype': 'markdown',
    \ 'ctagsbin' : '~/.awesome_devops/vim/plugged/markdown2ctags/markdown2ctags.py',
    \ 'ctagsargs' : '-f - --sort=yes',
    \ 'kinds' : [
        \ 's:sections',
        \ 'i:images'
    \ ],
    \ 'sro' : '|',
    \ 'kind2scope' : {
        \ 's' : 'section',
    \ },
    \ 'sort': 0,
\ }

"###########################
"# Status line
"###########################

" Always show the status line
set laststatus=2
set cmdheight=2
set scrolloff=10
set noshowmode

Plug 'bling/vim-airline'
Plug 'vim-airline/vim-airline-themes'
let g:airline_theme='base16_summerfruit'
let g:airline_section_b = ''
let g:airline_section_y = ''
"let g:airline#extensions#tagbar#flags = 'p'
let g:airline_powerline_fonts = 1
let g:airline_left_sep = ''
let g:airline_left_alt_sep = ''
let g:airline_right_sep = ''
let g:airline_right_alt_sep = ''
"let g:airline_powerline_fonts = 0
"let g:airline_left_sep = '▶'
"let g:airline_left_alt_sep = '❯'
"let g:airline_right_sep = '◀'
"let g:airline_right_alt_sep = '❮'
let g:airline#extensions#whitespace#enabled = 0
let g:airline#extensions#ale#enabled = 1
let g:airline#extensions#gutentags#enabled = 1
let g:airline_mode_map = {
  \ '__' : '-',
  \ 'n'  : 'N',
  \ 'i'  : 'I',
  \ 'R'  : 'R',
  \ 'c'  : 'C',
  \ 'v'  : 'V',
  \ 'V'  : 'V',
  \ '' : 'CV',
  \ 's'  : 'S',
  \ 'S'  : 'S',
  \ '' : 'S',
  \ }

"###########################
"# Misc
"###########################

Plug 'ZiYang-oyxy/vim-log-highlighting'

Plug 'osyo-manga/vim-over'
Plug 'scrooloose/nerdcommenter'

"" colorscheme
silent! syntax enable
if &term =~ '256color'
  " disable Background Color Erase (BCE) so that color schemes
  " render properly when inside 256-color tmux and GNU screen.
  " see also http://snk.tuxfamily.org/log/vim-256color-bce.html
  set t_ut=
endif
set t_Co=256

colorscheme darkburn_ie7

"Plug 'godlygeek/csapprox'
Plug 'mbbill/undotree'

" Lua
Plug 'xolox/vim-misc'
Plug 'xolox/vim-lua-inspect'
let g:lua_inspect_warnings = 0
let g:loaded_luainspect = 1
Plug 'xolox/vim-lua-ftplugin'
"Plug 'andrejlevkovitch/vim-lua-format'
"autocmd FileType lua nnoremap <buffer> <c-k> :call LuaFormat()<cr>
"autocmd BufWrite *.lua call LuaFormat()

" Snippet
Plug 'MarcWeber/vim-addon-mw-utils'
Plug 'tomtom/tlib_vim'
Plug 'garbas/vim-snipmate'
Plug 'honza/vim-snippets'
let g:snips_author = 'Ouyang Xiongyi'
let g:snipMate = { 'snippet_version' : 0 }
"Plug 'SirVer/ultisnips'
"let g:UltiSnipsExpandTrigger="<tab>"
"let g:UltiSnipsJumpForwardTrigger="<c-b>"
"let g:UltiSnipsJumpBackwardTrigger="<c-z>"
"let g:UltiSnipsEditSplit="vertical"

" Git
if executable('git')
    Plug 'tpope/vim-fugitive'
    Plug 'airblade/vim-gitgutter'
    let g:gitgutter_max_signs = 2000
    Plug 'gregsexton/gitv'
    let g:Gitv_OpenHorizontal = 1
    let g:Gitv_DoNotMapCtrlKey = 1
endif

Plug 'Lokaltog/vim-easymotion'
let g:EasyMotion_leader_key = '<Leader>'
"I just enable w and b action
let g:EasyMotion_mapping_f = ''
let g:EasyMotion_mapping_F = ''
let g:EasyMotion_mapping_t = ''
let g:EasyMotion_mapping_T = ''
"let g:EasyMotion_mapping_w = ''
let g:EasyMotion_mapping_W = ''
let g:EasyMotion_mapping_B = ''
let g:EasyMotion_mapping_e = ''
let g:EasyMotion_mapping_E = ''
let g:EasyMotion_mapping_ge = ''
let g:EasyMotion_mapping_gE = ''
let g:EasyMotion_mapping_j = ''
let g:EasyMotion_mapping_k = ''
let g:EasyMotion_mapping_n = ''
let g:EasyMotion_mapping_N = ''
Plug 'tpope/vim-surround'
Plug 'vim-scripts/DrawIt'
Plug 'vim-scripts/matrix.vim--Yang'
Plug 'vim-scripts/IndexedSearch'
Plug 'katonori/binedit'

Plug 'will133/vim-dirdiff'
let g:DirDiffExcludes = "CVS,*.class,*.exe,.*.swp,cscope.out.in,cscope.out,cscope.files,cscope.out.po,tags"

autocmd BufReadPost,FileReadPost,BufNewFile * call system("tmux rename-window " . expand("%"))

"###########################
"# Python lang
"###########################
"Plug 'python-mode/python-mode', { 'branch': 'develop' }
let g:pymode_options_max_line_length = 100
let g:pymode_rope_goto_definition_bind = '<leader>g'
Plug 'davidhalter/jedi-vim'
let g:jedi#added_sys_path = ["/opt/homebrew/lib/python3.10/site-packages"]
"Plug 'tell-k/vim-autopep8'
"let g:autopep8_max_line_length=79
"let g:autopep8_disable_show_diff=1

"###########################
"# Go lang
"###########################
"Plug 'fatih/vim-go', { 'for': 'go' }
" run :GoBuild or :GoTestCompile based on the go file
function! s:build_go_files()
  let l:file = expand('%')
  if l:file =~# '^\f\+_test\.go$'
    call go#cmd#Test(0, 1)
  elseif l:file =~# '^\f\+\.go$'
    call go#cmd#Build(0)
  endif
endfunction

autocmd FileType go nmap <leader>gb :<C-u>call <SID>build_go_files()<CR>
autocmd FileType go nmap <Leader>gc <Plug>(go-coverage-toggle)

let g:go_fmt_command = "goimports"
let g:go_highlight_types = 1
let g:go_highlight_fields = 1
let g:go_highlight_functions = 1
let g:go_highlight_methods = 1
let g:go_highlight_operators = 1
let g:go_highlight_extra_types = 1
let g:go_metalinter_autosave = 1
let g:go_metalinter_autosave_enabled = ['vet', 'golint']
let g:go_metalinter_deadline = "5s"
let g:go_auto_type_info = 1
"let g:go_auto_sameids = 1

"###########################
"# cpp lang
"###########################
Plug 'octol/vim-cpp-enhanced-highlight'
Plug 'bfrg/vim-cuda-syntax'
" Enable highlighting of CUDA kernel calls
let g:cuda_kernel_highlight = 1
" Highlight keywords from CUDA Runtime API
let g:cuda_runtime_api_highlight = 1
" Highlight keywords from CUDA Driver API
let g:cuda_driver_api_highlight = 1
" Highlight keywords from CUDA Thrust library
let g:cuda_thrust_highlight = 1

"###########################
"# bash lang
"###########################
Plug 'z0mbix/vim-shfmt'

"###########################
"# bpftrace lang
"###########################
Plug 'mmarchini/bpftrace.vim'

"###########################
"# Code helper
"###########################
Plug 'MattesGroeger/vim-bookmarks'
let g:bookmark_location_list = 0
let g:bookmark_disable_ctrlp = 0
highlight BookmarkSign ctermbg=NONE ctermfg=160
let g:bookmark_sign = '♥'
"let g:bookmark_highlight_lines = 1

" Plug 'github/copilot.vim'
" imap <silent><script><expr> <C-L> copilot#Accept("\<CR>")
" let g:copilot_no_tab_map = v:true

Plug 'Yggdroot/indentLine'

"###########################
"# tags
"###########################
Plug 'inkarkat/vim-ingo-library'
Plug 'ZiYang-oyxy/vim-mark'
set viminfo+=!
let g:mwIgnoreCase = 0
let g:mwDefaultHighlightingNum = 15
let g:mwDefaultHighlightingPalette = 'extended'
nmap <Leader>` :Marks<CR>
nmap <Leader>1 <Plug>MarkSearchGroup1Next
nmap <Leader>2 <Plug>MarkSearchGroup2Next
nmap <Leader>3 <Plug>MarkSearchGroup3Next
nmap <Leader>4 <Plug>MarkSearchGroup4Next
nmap <Leader>5 <Plug>MarkSearchGroup5Next
nmap <Leader>6 <Plug>MarkSearchGroup6Next
nmap <Leader>7 <Plug>MarkSearchGroup7Next
nmap <Leader>8 <Plug>MarkSearchGroup8Next
nmap <Leader>9 <Plug>MarkSearchGroup9Next

"###########################
"# cscope
"###########################

" ================= use gtags_cscope ========================
" brew install global
" brew install universal-ctags
if !(has('job') || (has('nvim') && exists('*jobwait')))
else
    Plug 'ludovicchabant/vim-gutentags'
endif

" enable gtags module
"let g:gutentags
let g:gutentags_modules = ['ctags', 'gtags_cscope']

" config project root markers.
let g:gutentags_add_default_project_roots=0
let g:gutentags_project_root = ['.root', '.git']
let g:gutentags_generate_on_empty_buffer=1

"" generate datebases in my cache directory, prevent gtags files polluting my project
"let g:gutentags_cache_dir = expand('~/.awesome_devops/vim/cache/tags')

set statusline+=%{gutentags#statusline()}

" Useful debug
"let g:gutentags_trace = 1

let g:gutentags_ctags_exclude = [
    \ '*/freebsd/*',
    \ '*/windows/*',
    \ '*.log',
    \ '*.log.[0-9]*',
    \ 'node_modules'
\]

" ================= use dynamic cscope ========================
Plug 'ZiYang1989/cscope_dynamic'
let g:cscopedb_big_file = "cscope.out"
let g:cscopedb_auto_files = 0
let g:cscopedb_extra_files = "cscope.files"
let g:cscopedb_big_min_interval = 60
let g:statusline_cscope_flag = ""

" ================= cscope common config ========================
if has("cscope")
    set csto=1
    set cst
    set nocsverb
    set csverb
    set cscopequickfix=s-,g-,c-,t-,e-,f-,i-,d-
endif
"s: Find this C symbol
"g: Find this definition
"c: Find functions calling this function
"t: Find this text string
"d: Find functions called by this function
"e: Find this egrep pattern
"f: Find this file
"i: Find files #including this file
noremap <C-@>s :cs find s <C-R>=expand("<cword>")<CR><CR>
noremap <C-@>g :cs find g <C-R>=expand("<cword>")<CR><CR>
noremap <C-@>c :cs find c <C-R>=expand("<cword>")<CR><CR>
noremap <C-@>t :cs find t <C-R>=expand("<cword>")<CR><CR>
noremap <C-@>d :cs find d <C-R>=expand("<cword>")<CR><CR>
noremap <C-@>e :cs find e <C-R>=expand("<cword>")<CR><CR>
noremap <C-@>f :cs find f <C-R>=expand("<cfile>")<CR><CR>
noremap <C-@>i :cs find i ^<C-R>=expand("<cfile>")<CR>$<CR>
function! SwitchSourceHeader()
    cs find f %:t:r.h
endfunction
noremap <C-@>h :call SwitchSourceHeader()<CR>
map <F6> :cs find g<space>

Plug 'skywind3000/vim-preview'
nnoremap <silent> \ :PreviewTag<CR>
nnoremap <silent> <leader>\ :PreviewClose<CR>
autocmd FileType qf nnoremap <silent><buffer> \ :PreviewQuickfix<cr>
autocmd FileType qf nnoremap <silent><buffer> <leader>\ :PreviewClose<cr>

"###########################
"# COC
"###########################
if executable('node')
    Plug 'neoclide/coc.nvim', {'branch': 'release'}
endif

" Use K to show documentation in preview window.
nnoremap <silent> K :call ShowDocumentation()<CR>
function! ShowDocumentation()
  if CocAction('hasProvider', 'hover')
    call CocActionAsync('doHover')
  else
    call feedkeys('K', 'in')
  endif
endfunction

"" Use tab for trigger completion with characters ahead and navigate.
"" NOTE: Use command ':verbose imap <tab>' to make sure tab is not mapped by
"" other plugin before putting this into your config.
"inoremap <silent><expr> <TAB>
"      \ pumvisible() ? "\<C-n>" :
"      \ CheckBackspace() ? "\<TAB>" :
"      \ coc#refresh()
"inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"
"
"function! CheckBackspace() abort
"  let col = col('.') - 1
"  return !col || getline('.')[col - 1]  =~# '\s'
"endfunction

"###########################
"# General
"###########################
let g:netrw_dirhistmax=0

" linux下设置长按的按键速率，mac下不需要
"xset r rate 330 50

" fix backspace not working:
" http://stackoverflow.com/questions/11560201/backspace-key-not-working-in-vim-vi
set backspace=indent,eol,start

" Return to last edit position when opening files (You want this!)
autocmd BufReadPost *
     \ if line("'\"") > 0 && line("'\"") <= line("$") |
     \   exe "normal! g`\"" |
     \ endif
autocmd! bufwritepost .vimrc source ~/.awesome_devops/vim/.vimrc
autocmd BufEnter * let &titlestring = ' ' . expand("%:t")
set title
set textwidth=0
set nu

set lcs=tab:>-,trail:-
"set lcs=tab:\ \ ,trail:\ 
"set nonumber
set list

set expandtab
set tabstop=4
set shiftwidth=4
"set tabstop=8
"set shiftwidth=8
nnoremap <F2> :set invexpandtab<CR>

set fileformats=unix,dos
set autoindent
set fileencodings=ucs-bom,utf-8,chinese
set showcmd
set foldlevel=50
set autoread
set wildmenu
set wildignore=*.o,*~,*.pyc
if has('mouse')
    set mouse=a
endif

" Search
"set incsearch
set hlsearch
set ignorecase
set smartcase

" persistent undo
set undofile
set undodir=~/.awesome_devops/vim/undodir

" for mintty
set encoding=utf-8
"set guifont="Consolas for Powerline FixedD:h9"

"###########################
"# Map leader
"###########################
map <leader>ss :source ~/.awesome_devops/vim/.vimrc<CR>:noh<CR>
map <leader>ee :e ~/.awesome_devops/vim/.vimrc<CR>
map <leader><CR> :MarkClear<CR>:noh<CR>
map <leader>a A
map <leader>q :qa!<CR>

fun! TrimWhitespace()
    let l:save = winsaveview()
    keeppatterns %s/\s\+$//e
    call winrestview(l:save)
endfun

fun! TrimM()
    let l:save = winsaveview()
    keeppatterns %s/\+$//e
    call winrestview(l:save)
endfun

" Remove the Windows ^M - when the encodings gets messed up
noremap <Leader>fm :call TrimM()<CR>

" Strip space, and fix some bug at the same time
noremap <Leader>ts :call TrimWhitespace()<CR>

" Use four spaces to replace a tab
map <leader>ft :retab<CR>

" Copy to CLIPBOARD, and use 'y' to copy to the PRIMARY
map <leader>y "+y
map <leader>p "+p

" When you press <leader>r you can search and replace the selected text
" append /g to the end to replace all
vmap <leader>r y:%s/<C-R>0/

" Useful mappings for managing tabs
map <leader>tn :tabnew<cr>
map <leader>to :tabonly<cr>
map <leader>tc :tabclose<cr>
map <leader>tm :tabmove

" save all files
noremap S :wa<CR>

" Move between windows
map <C-j> <C-w>j
map <C-k> <C-w>k
map <C-l> <C-w>l
map <C-h> <C-w>h

" replaced by <C-c>
nmap - ^
nmap = $
vmap - ^
vmap = $

" use Q for recording
noremap q <Nop>
noremap Q q

" Open a fully width quickfix window at the bottom of vim
Plug 'milkypostman/vim-togglelist'
let g:toggle_list_no_mappings=1
nmap <script> <silent> <F9> :call ToggleQuickfixList()<CR>

" if you want to load the quickfix item into the previously used window.
silent! set switchbuf+=uselast

map <F3> :cp<CR>
map <F4> :cn<CR>

" Look up dictionary, cover IndexedSearch's map
autocmd! VimEnter * :nnoremap ? :!~/.awesome_devops/tools/youdao <C-R>=expand("<cword>")<CR><CR>
vmap ? y:!~/.awesome_devops/tools/youdao <C-R>0<CR>

" pretty format json string
vmap <leader>fj :!python3 -m json.tool<CR>

" pretty format c code
vmap <leader>fc :!clang-format -style=file<CR>
nmap <leader>fc ggvG<leader>fc<C-o><C-o>

" pretty format python code
map <leader>fp :PymodeLintAuto<CR>

" pretty format shell code
map <leader>fs :Shfmt -i 4<CR>

" Auto convert a word to a shell variable
imap <C-h> <ESC>bi"$<ESC>ea"
imap <C-g> <ESC>bi$(<ESC>ea)

" jump to the match brace
map ]] ]}
map [[ [{

map f- zM
map f= zR

"###########################
"# Helper functions
"###########################
au FileType qf call AdjustWindowHeight(3, 20)
function! AdjustWindowHeight(minheight, maxheight)
	let l = 1
	let n_lines = 0
	let w_width = winwidth(0)
	while l <= line('$')
		" number to float for division
		let l_len = strlen(getline(l)) + 0.0
		let line_width = l_len/w_width
		let n_lines += float2nr(ceil(line_width))
		let l += 1
	endw
	exe max([min([n_lines, a:maxheight]), a:minheight]) . "wincmd _"
endfunction

nmap <F12> <Plug>CscopeDBInit

set shortmess+=A
call plug#end()
