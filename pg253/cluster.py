import re
from datetime import datetime, timedelta
from subprocess import run

from pg253.transfer import Transfer
from pg253.remote import Remote
from pg253.configuration import Configuration


class Cluster:
    def __init__(self, metrics):
        self.running = False
        self.metrics = metrics
        self.db_exclude = \
            re.compile(Configuration.get('blacklisted_databases'))

    def listDatabase(self):
        cmd = ['psql', '-qAtX', '-c', 'SELECT datname FROM pg_database']
        res = run(cmd, capture_output=True)
        if res.returncode != 0:
            raise Exception('Unable to retrieve database list: %s'
                            % res.stderr.decode())
        dbs = res.stdout.decode().strip().split("\n")
        dbs = list(filter(lambda x: not self.db_exclude.search(x), dbs))
        dbs.remove('template0')
        return dbs

    def backup_and_prune(self, *unused):
        if not self.running:
            try:
                self.running = True
                print("Backup...")
                self.backup()
                print("Prune...")
                self.prune()
                self.running = False
                self.metrics.error.labels('').set(0)
            except Exception as e:
                self.running = False
                self.metrics.error.labels('').set(1)
                raise e
        else:
            print('Backup already running')

    def backup(self):
        for database in self.listDatabase():
            try:
                Transfer(database, self.metrics).run()
                self.metrics.error.labels(database).set(0)
            except Exception as e:
                self.metrics.error.labels(database).set(1)
                raise e


    def prune(self):
        # Compute date of oldest backup we need to keep
        delete_before = \
            (datetime.now()
             - timedelta(days=float(Configuration.get('retention_days'))))
        for database in Remote.BACKUPS:
            for to_delete in [backup for backup in Remote.BACKUPS[database]
                              if backup[0] < delete_before]:
                print("Remove backup of '%s' at %s" % (database, to_delete[0]))
                Remote.delete(database, to_delete[0], to_delete[1])
                self.metrics.removeBackup(database, to_delete[0], to_delete[1])
