#to edit source files:
foreach i ($argv)
   mv $i:r.body $i:r.before
   sed -e '1,/pagecount : integer/d' -e '/tabcount : integer/,/	    end;/d' <$i:r.before >$i:r.body
end
