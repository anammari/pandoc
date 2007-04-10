{-
Copyright (C) 2006 John MacFarlane <jgm at berkeley dot edu>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
-}

{- |
   Module      : Text.Pandoc.Writers.Markdown 
   Copyright   : Copyright (C) 2006 John MacFarlane
   License     : GNU GPL, version 2 or above 

   Maintainer  : John MacFarlane <jgm at berkeley dot edu>
   Stability   : alpha
   Portability : portable

Conversion of 'Pandoc' documents to markdown-formatted plain text.

Markdown:  <http://daringfireball.net/projects/markdown/>
-}
module Text.Pandoc.Writers.Markdown (
                                     writeMarkdown
                                    ) where
import Text.Pandoc.Definition
import Text.Pandoc.Shared 
import Data.List ( group, isPrefixOf, drop, find )
import Text.PrettyPrint.HughesPJ hiding ( Str )
import Control.Monad.State

type Notes = [[Block]]
type Refs = KeyTable
type WriterState = (Notes, Refs)

-- | Convert Pandoc to Markdown.
writeMarkdown :: WriterOptions -> Pandoc -> String
writeMarkdown opts document = 
  render $ evalState (pandocToMarkdown opts document) ([],[]) 

-- | Return markdown representation of document.
pandocToMarkdown :: WriterOptions -> Pandoc -> State WriterState Doc
pandocToMarkdown opts (Pandoc meta blocks) = do
  let before  = writerIncludeBefore opts
  let after   = writerIncludeAfter opts
      before' = if null before then empty else text before
      after'  = if null after then empty else text after
  metaBlock <- metaToMarkdown opts meta
  let head = if (writerStandalone opts)
                then metaBlock $$ text (writerHeader opts)
                else empty
  body <- blockListToMarkdown opts blocks
  (notes, _) <- get
  notes' <- notesToMarkdown opts (reverse notes)
  (_, refs) <- get  -- note that the notes may contain refs
  refs' <- keyTableToMarkdown opts (reverse refs)
  return $ head <> (before' $$ body <> text "\n" $$ 
                    notes' <> text "\n" $$ refs' $$ after')

-- | Return markdown representation of reference key table.
keyTableToMarkdown :: WriterOptions -> KeyTable -> State WriterState Doc
keyTableToMarkdown opts refs = 
  mapM (keyToMarkdown opts) refs >>= (return . vcat)
 
-- | Return markdown representation of a reference key. 
keyToMarkdown :: WriterOptions 
              -> ([Inline], (String, String)) 
              -> State WriterState Doc
keyToMarkdown opts (label, (src, tit)) = do
  label' <- inlineListToMarkdown opts label
  let tit' = if null tit then empty else text $ " \"" ++ tit ++ "\""
  return $ text "  " <> char '[' <> label' <> char ']' <> text ": " <>
           text src <> tit' 

-- | Return markdown representation of notes.
notesToMarkdown :: WriterOptions -> [[Block]] -> State WriterState Doc
notesToMarkdown opts notes = 
  mapM (\(num, note) -> noteToMarkdown opts num note) (zip [1..] notes) >>= 
  (return . vcat)

-- | Return markdown representation of a note.
noteToMarkdown :: WriterOptions -> Int -> [Block] -> State WriterState Doc
noteToMarkdown opts num note = do
  contents <- blockListToMarkdown opts note
  let marker = text "[^" <> text (show num) <> text "]:"
  return $ hang marker (writerTabStop opts) contents 

wrappedMarkdown :: WriterOptions -> [Inline] -> State WriterState Doc
wrappedMarkdown opts sect = do
  let chunks = splitBy Space sect
  chunks' <- mapM (inlineListToMarkdown opts) chunks
  return $ fsep chunks'

-- | Escape nonbreaking space as &nbsp; entity
escapeNbsp "" = ""
escapeNbsp ('\160':xs) = "&nbsp;" ++ escapeNbsp xs
escapeNbsp str = 
  let (a,b) = break (=='\160') str in
  a ++ escapeNbsp b

-- | Escape special characters for Markdown.
escapeString :: String -> String
escapeString = backslashEscape "`<\\*_^" . escapeNbsp

-- | Convert bibliographic information into Markdown header.
metaToMarkdown :: WriterOptions -> Meta -> State WriterState Doc
metaToMarkdown opts (Meta title authors date) = do
  title'   <- titleToMarkdown opts title
  authors' <- authorsToMarkdown authors
  date'    <- dateToMarkdown date
  return $ title' <> authors' <> date'

titleToMarkdown :: WriterOptions -> [Inline] -> State WriterState Doc
titleToMarkdown opts [] = return empty
titleToMarkdown opts lst = do
  contents <- inlineListToMarkdown opts lst
  return $ text "% " <> contents <> text "\n"

authorsToMarkdown :: [String] -> State WriterState Doc
authorsToMarkdown [] = return empty
authorsToMarkdown lst = return $ 
  text "% " <> text (joinWithSep ", " (map escapeString lst)) <> text "\n"

dateToMarkdown :: String -> State WriterState Doc
dateToMarkdown [] = return empty
dateToMarkdown str = return $ text "% " <> text (escapeString str) <> text "\n"

-- | Convert Pandoc block element to markdown.
blockToMarkdown :: WriterOptions -- ^ Options
                -> Block         -- ^ Block element
                -> State WriterState Doc 
blockToMarkdown opts Null = return empty
blockToMarkdown opts (Plain inlines) = wrappedMarkdown opts inlines
blockToMarkdown opts (Para inlines) = do
  contents <- wrappedMarkdown opts inlines
  return $ contents <> text "\n"
blockToMarkdown opts (RawHtml str) = return $ text str
blockToMarkdown opts HorizontalRule = return $ text "\n* * * * *\n"
blockToMarkdown opts (Header level inlines) = do
  contents <- inlineListToMarkdown opts inlines
  return $ text ((replicate level '#') ++ " ") <> contents <> text "\n"
blockToMarkdown opts (CodeBlock str) = return $
  (nest (writerTabStop opts) $ vcat $ map text (lines str)) <> text "\n"
blockToMarkdown opts (BlockQuote blocks) = do
  contents <- blockListToMarkdown opts blocks
  let quotedContents = unlines $ map ("> " ++) $ lines $ render contents
  return $ text quotedContents 
blockToMarkdown opts (Table caption _ _ headers rows) = blockToMarkdown opts 
  (Para [Str "pandoc: TABLE unsupported in Markdown writer"])
blockToMarkdown opts (BulletList items) = do
  contents <- mapM (bulletListItemToMarkdown opts) items
  return $ (vcat contents) <> text "\n"
blockToMarkdown opts (OrderedList items) = do
  contents <- mapM (\(item, num) -> orderedListItemToMarkdown opts item num) $
              zip [1..] items  
  return $ (vcat contents) <> text "\n"

-- | Convert bullet list item (list of blocks) to markdown.
bulletListItemToMarkdown :: WriterOptions -> [Block] -> State WriterState Doc
bulletListItemToMarkdown opts items = do
  contents <- blockListToMarkdown opts items
  return $ hang (text "-  ") (writerTabStop opts) contents

-- | Convert ordered list item (a list of blocks) to markdown.
orderedListItemToMarkdown :: WriterOptions -- ^ options
                          -> Int           -- ^ ordinal number of list item
                          -> [Block]       -- ^ list item (list of blocks)
                          -> State WriterState Doc
orderedListItemToMarkdown opts num items = do
  contents <- blockListToMarkdown opts items
  let spacer = if (num < 10) then " " else ""
  return $ hang (text ((show num) ++ "." ++ spacer)) (writerTabStop opts)
           contents 

-- | Convert list of Pandoc block elements to markdown.
blockListToMarkdown :: WriterOptions -- ^ Options
                    -> [Block]       -- ^ List of block elements
                    -> State WriterState Doc 
blockListToMarkdown opts blocks =
  mapM (blockToMarkdown opts) blocks >>= (return . vcat)

-- | Get reference for target; if none exists, create unique one and return.
--   Prefer label if possible; otherwise, generate a unique key.
getReference :: [Inline] -> Target -> State WriterState [Inline]
getReference label (src, tit) = do
    (_,refs) <- get
    case find ((== (src, tit)) . snd) refs of
      Just (ref, _) -> return ref
      Nothing       -> do
        let label' = case find ((== label) . fst) refs of
                        Just _ -> -- label is used; generate numerical label
                                   case find (\n -> not (any (== [Str (show n)])
                                             (map fst refs))) [1..10000] of
                                        Just x  -> [Str (show x)]
                                        Nothing -> error "no unique label"
                        Nothing -> label
        modify (\(notes, refs) -> (notes, (label', (src,tit)):refs))
        return label'

-- | Convert list of Pandoc inline elements to markdown.
inlineListToMarkdown :: WriterOptions -> [Inline] -> State WriterState Doc
inlineListToMarkdown opts lst = mapM (inlineToMarkdown opts) lst >>= (return . hcat)

-- | Convert Pandoc inline element to markdown.
inlineToMarkdown :: WriterOptions -> Inline -> State WriterState Doc
inlineToMarkdown opts (Emph lst) = do 
  contents <- inlineListToMarkdown opts lst
  return $ text "*" <> contents <> text "*"
inlineToMarkdown opts (Strong lst) = do
  contents <- inlineListToMarkdown opts lst
  return $ text "**" <> contents <> text "**"
inlineToMarkdown opts (Quoted SingleQuote lst) = do
  contents <- inlineListToMarkdown opts lst
  return $ char '\'' <> contents <> char '\''
inlineToMarkdown opts (Quoted DoubleQuote lst) = do
  contents <- inlineListToMarkdown opts lst
  return $ char '"' <> contents <> char '"'
inlineToMarkdown opts EmDash = return $ text "--"
inlineToMarkdown opts EnDash = return $ char '-'
inlineToMarkdown opts Apostrophe = return $ char '\''
inlineToMarkdown opts Ellipses = return $ text "..."
inlineToMarkdown opts (Code str) =
  let tickGroups = filter (\s -> '`' `elem` s) $ group str 
      longest    = if null tickGroups
                     then 0
                     else maximum $ map length tickGroups 
      marker     = replicate (longest + 1) '`' 
      spacer     = if (longest == 0) then "" else " " in
  return $ text (marker ++ spacer ++ str ++ spacer ++ marker)
inlineToMarkdown opts (Str str) = return $ text $ escapeString str
inlineToMarkdown opts (TeX str) = return $ text str
inlineToMarkdown opts (HtmlInline str) = return $ text str 
inlineToMarkdown opts (LineBreak) = return $ text "  \n"
inlineToMarkdown opts Space = return $ char ' '
inlineToMarkdown opts (Link txt (src, tit)) = do
  linktext <- inlineListToMarkdown opts txt
  let linktitle = if null tit then empty else text $ " \"" ++ tit ++ "\""
  let srcSuffix = if isPrefixOf "mailto:" src then drop 7 src else src
  let useRefLinks = writerReferenceLinks opts
  let useAuto = null tit && txt == [Str srcSuffix]
  ref <- if useRefLinks then getReference txt (src, tit) else return []
  reftext <- inlineListToMarkdown opts ref
  return $ if useAuto
              then char '<' <> text srcSuffix <> char '>' 
              else if useRefLinks
                  then let first  = char '[' <> linktext <> char ']'
                           second = if txt == ref
                                      then text "[]"
                                      else char '[' <> reftext <> char ']'
                       in  first <> second
                  else char '[' <> linktext <> char ']' <> 
                       char '(' <> text src <> linktitle <> char ')' 
inlineToMarkdown opts (Image alternate (source, tit)) = do
  let txt = if (null alternate) || (alternate == [Str ""]) || 
               (alternate == [Str source]) -- to prevent autolinks
               then [Str "image"]
               else alternate
  linkPart <- inlineToMarkdown opts (Link txt (source, tit)) 
  return $ char '!' <> linkPart
inlineToMarkdown opts (Note contents) = do 
  modify (\(notes, refs) -> (contents:notes, refs)) -- add to notes in state
  (notes, _) <- get
  let ref = show $ (length notes)
  return $ text "[^" <> text ref <> char ']'
