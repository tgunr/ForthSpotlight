
: test.fth-defintion ( color x y w h -- )
    " fill-rectangle" myscreen $call-method ;
   
CODE test.fth-code ( ms -- pos.x pos.y buttons true|false )
    " get-event" mymouse $call-method 
   
TCODE test.fth-tcode