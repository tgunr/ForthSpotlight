
: test.fs-defintion ( color x y w h -- )
    " fill-rectangle" myscreen $call-method ;
   
CODE test.fs-code ( ms -- pos.x pos.y buttons true|false )
    " get-event" mymouse $call-method 
   
TCODE test.fs-tcode