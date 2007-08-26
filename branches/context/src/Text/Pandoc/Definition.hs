{-
Copyright (C) 2006-7 John MacFarlane <jgm@berkeley.edu>

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
   Module      : Text.Pandoc.Definition
   Copyright   : Copyright (C) 2006-7 John MacFarlane
   License     : GNU GPL, version 2 or above 

   Maintainer  : John MacFarlane <jgm@berkeley.edu>
   Stability   : alpha
   Portability : portable

Definition of 'Pandoc' data structure for format-neutral representation
of documents.
-}
module Text.Pandoc.Definition where

data Pandoc = Pandoc Meta [Block] deriving (Eq, Read, Show)

-- | Bibliographic information for the document:  title (list of 'Inline'),
-- authors (list of strings), date (string).
data Meta   = Meta [Inline] -- title
                   [String] -- authors
                   String   -- date
              deriving (Eq, Show, Read)

-- | Alignment of a table column.
data Alignment = AlignLeft 
               | AlignRight 
               | AlignCenter 
               | AlignDefault deriving (Eq, Show, Read)

-- | Block element.
data Block  
    = Plain [Inline]        -- ^ Plain text, not a paragraph
    | Null                  -- ^ Nothing
    | Para [Inline]         -- ^ Paragraph
    | CodeBlock String      -- ^ Code block (literal)
    | RawHtml String        -- ^ Raw HTML block (literal)
    | BlockQuote [Block]    -- ^ Block quote (list of blocks)
    | OrderedList [[Block]] -- ^ Ordered list (list of items, each 
                            -- a list of blocks)
    | BulletList [[Block]]  -- ^ Bullet list (list of items, each
                            -- a list of blocks)
    | DefinitionList [([Inline],[Block])]  -- ^ Definition list 
                            -- (list of items, each a pair of an inline list,
                            -- the term, and a block list)
    | Header Int [Inline]   -- ^ Header - level (integer) and text (inlines) 
    | HorizontalRule        -- ^ Horizontal rule
    | Table [Inline] [Alignment] [Float] [[Block]] [[[Block]]]  -- ^ Table,
                            -- with caption, column alignments,
                            -- relative column widths, column headers
                            -- (each a list of blocks), and rows
                            -- (each a list of lists of blocks)
    deriving (Eq, Read, Show)

-- | Type of quotation marks to use in Quoted inline.
data QuoteType = SingleQuote | DoubleQuote deriving (Show, Eq, Read)

type Target = (String, String)  -- ^ Link target (URL, title)

-- | Inline elements.
data Inline 
    = Str String            -- ^ Text (string)
    | Emph [Inline]         -- ^ Emphasized text (list of inlines)
    | Strong [Inline]       -- ^ Strongly emphasized text (list of inlines)
    | Quoted QuoteType [Inline] -- ^ Quoted text (list of inlines)
    | Code String           -- ^ Inline code (literal)
    | Space                 -- ^ Inter-word space
    | EmDash                -- ^ Em dash
    | EnDash                -- ^ En dash
    | Apostrophe            -- ^ Apostrophe
    | Ellipses              -- ^ Ellipses
    | LineBreak             -- ^ Hard line break
    | TeX String            -- ^ LaTeX code (literal)
    | HtmlInline String     -- ^ HTML code (literal)
    | Link [Inline] Target  -- ^ Hyperlink: text (list of inlines), target
    | Image [Inline] Target -- ^ Image:  alt text (list of inlines), target
                            -- and target
    | Note [Block]          -- ^ Footnote or endnote - reference (string),
                            -- text (list of blocks)
    deriving (Show, Eq, Read)