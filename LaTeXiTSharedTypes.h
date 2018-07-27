/*
 *  LaTeXiTTypes.h
 *  LaTeXiT
 *
 *  Created by Pierre Chatelier on 25/09/08.
 *  Copyright 2008 LAIC. All rights reserved.
 *
 */

//useful to differenciate the different latex modes : EQNARRAY, DISPLAY (\[...\]), INLINE ($...$) and TEXT (text)
typedef enum {LATEX_MODE_DISPLAY, LATEX_MODE_INLINE, LATEX_MODE_TEXT, LATEX_MODE_EQNARRAY} latex_mode_t;

typedef enum {EXPORT_FORMAT_PDF, EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS,
              EXPORT_FORMAT_EPS, EXPORT_FORMAT_TIFF, EXPORT_FORMAT_PNG, EXPORT_FORMAT_JPEG} export_format_t;

typedef enum {COMPOSITION_MODE_PDFLATEX, COMPOSITION_MODE_LATEXDVIPDF, COMPOSITION_MODE_XELATEX} composition_mode_t;
typedef enum {SCRIPT_SOURCE_STRING, SCRIPT_SOURCE_FILE} script_source_t;
typedef enum {SCRIPT_PLACE_PREPROCESSING, SCRIPT_PLACE_MIDDLEPROCESSING, SCRIPT_PLACE_POSTPROCESSING} script_place_t;
