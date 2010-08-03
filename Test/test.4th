
: test.4th-defintion ( color x y w h -- )
    " fill-rectangle" myscreen $call-method ;
   
CODE test.4th-code ( ms -- pos.x pos.y buttons true|false )
    " get-event" mymouse $call-method 
   
TCODE test.4th-tcode