# Phoexnip

## Development Setup

```bash
sudo apt purge erlang* elixir* postgres*
mise install
mise use --global $(awk '{printf "%s@%s ",$1,$2}' .tool-versions)

rm -rf ~/.local/share/postgres/data
mkdir -p ~/.local/share/postgres/data
initdb -D ~/.local/share/postgres/data --username=postgres --auth-local=trust --auth-host=md5
grep -qxF 'export PGHOST=/tmp/' ~/.bashrc || echo 'export PGHOST=/tmp/' >> ~/.bashrc
eval export PGHOST=/tmp/
source ~/.bashrc
mkdir -p ~/.config/autostart/ && echo -e "[Desktop Entry]\nType=Application\nExec=bash -c \"mise exec -- pg_ctl -D ~/.local/share/postgres/data -l ~/logfile start\"\nHidden=false\nNoDisplay=false\nX-GNOME-Autostart-enabled=true\nName=Start Postgres" > ~/.config/autostart/postgres-startup.desktop
mise exec -- pg_ctl -D ~/.local/share/postgres/data -l ~/logfile start
psql -U postgres -c "SET password_encryption = 'scram-sha-256';"
psql -U postgres -c "ALTER USER postgres WITH PASSWORD 'postgres';"

mix reset.hard
```

* Run ``mix phx.server`` to start the server at [`localhost:4000`](http://localhost:4000) for your browser.

### Updating mise.toml

Specify the new versions in mise.toml:

* Open the terminal in the repository directory and run the following command to set your global environment to follow the mise.toml:

```bash
mise use --global $(awk '{printf "%s@%s ",$1,$2}' mise.toml)
```

* Run the following in order **only if** `postgres` version is updated in terminal to re-init / migrate the database for the new version:

```bash
mkdir -p ~/.local/share/pg/dumps
pg_dumpall -U postgres > ~/.local/share/pg/dumps/$(date +%Y%m%d%H%M).sql

pg_ctl -D ~/.local/share/postgres/data -l ~/logfile stop
rm -rf ~/.local/share/postgres/data
mkdir -p ~/.local/share/postgres/data
initdb -D ~/.local/share/postgres/data --username=postgres --auth-local=trust --auth-host=md5
pg_ctl -D ~/.local/share/postgres/data -l ~/logfile start -o "-k /tmp"
psql -U postgres -c "ALTER USER postgres WITH PASSWORD 'postgres';"

psql -U postgres -f $(ls -1t ~/.local/share/pg/dumps/*.sql | head -1)
```

* You can continue with the development normally.

### Renaming the project

```bash
sudo ack -l Phoexnip | xargs sudo sed -i -e "s/Phoexnip/Projectname/g"
sudo ack -l phoexnip | xargs sudo sed -i -e "s/phoexnip/projectname/g"
sudo mv lib/phoexnip lib/projectname
sudo mv lib/phoexnip.ex lib/projectname.ex
sudo mv lib/phoexnip_web lib/projectname_web
sudo mv lib/phoexnip_web.ex lib/projectname_web.ex
sudo mv test/phoexnip test/projectname
sudo mv test/phoexnip_web test/projectname_web
```