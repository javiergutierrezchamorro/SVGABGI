# ifndef __PALETTE_H__
# define __PALETTE_H__


enum FADE_MODE
{
    FADE_UP,
    FADE_DOWN,
    FADE_BLACKOUT,
    FADE_RESTORE
} ;

int  fade              (enum fade_mode modus, int steps, int milli);
void plane             (void);
void setuniformpalette (void);
void set32palette      (void);
void set32Hpalette     (void);
void set64palette      (void);
void setflowpalette    (void);

# endif __PALETTE_H__


