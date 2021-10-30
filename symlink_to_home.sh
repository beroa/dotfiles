me=`basename "$0"`

for f in .*; do 
	#echo $f;
	if [ $f != $me ] && [ $f != '.git' ] && [ $f != '.' ] && [ $f != '..' ]; then
		ln -s $PWD/$f $HOME
	fi;
done

