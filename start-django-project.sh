#cleanup first
dropdb $1 #drop Postgresql database
rmvirtualenv $1 #remove virtualenv
rm -r ~/projects/$1 #remove project folder

#now initialize project
createdb $1
mkvirtualenv $1
workon $1
pip install django #have to install Django first
cd ~/projects
django-admin.py startproject --template https://github.com/rolph-recto/django_project_template/zipball/master $1
cd ~/projects/$1
setvirtualenvproject
pip install -r ~/projects/$1/requirements/local.txt
python manage.py syncdb
python manage.py migrate
git init
git add --all
git commit -m "Initial commit"
