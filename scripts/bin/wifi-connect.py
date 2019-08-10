#!/usr/bin/python

"""a simple standalone script to connect to a WPA, WEP or OPN network"""
from __future__ import print_function

from subprocess import call, check_output
import argparse
import getpass
import logging
import os
import re
import subprocess
import time

logging.basicConfig()
logger = logging.getLogger("wifi-connect")

def call_check(*args, **kwargs):
    "proxy to subprocess.call, raising error on non-zero status"
    cmd = args[0]
    logger.debug("calling: %s", " ".join(cmd))
    recode = subprocess.call(*args, **kwargs)
    if recode != 0:
        raise Exception("non-zero exit status")

def pkill(proc):
    call(["sudo", "pkill", proc])

def selcand(cands, display_fun=str, error="no choices available"):
    "interactively select a candidate from a list"
    if not cands:
        raise Exception(error)
    elif len(cands) == 1:
        return cands[0]
    else:
        print ("\n".join("{}: {}".format(i, display_fun(cand)) for (i, cand) in enumerate(cands)))
        idx_string = raw_input("enter selection index: ")
        try:
            return cands[int(idx_string)]
        except IndexError:
            return selcand(cands, display_fun)

def iface_list():
    "discover the available wifi interfaces"
    ifconfig_out = check_output(["ifconfig", "-a"])
    m = re.findall("(?m)^wlan[0-9]+|wlp[^:]+", ifconfig_out)
    return list(set(m))

def known_essids_list(directory):
    "read the list of known essids or access points"
    return os.listdir(directory)


class Cell(object):
    class Encryptions(object):
        WPA = "WPA"
        WPA2 = "WPA2"
        WEP = "WEP"

    def __init__(self, scan_output=None):
        self.essid = None
        self.bssid = None
        self.channel = None
        self.signal = None
        self.frequency = None
        self.iface = None
        self.wpa = None
        self.encryption = None
        self.signal_integer = None
        if scan_output:
            self.__init_from_scan_output__(scan_output)

    def __init_from_scan_output__(self, scan_output):
        for (attr, regexp) in (
                ("bssid", "^ *([a-f0-9:]+)"),
                ("iface", "^.*\\(on (.*)\\)"),
                ("essid", "SSID: (.*)"),
                ("signal", "signal:(.*)"),
                ("channel", "channel:(.*)"),
                ("wpa", "WPA (Version .*)"),
                ("freq", "frequency:(.*)"),
                ("quality", "quality=(.*)"),
                ("enc", "encryption key:(.*)"),
                ("wpa2", "WPA2 (Version .*)")):
            m = re.search(regexp, scan_output)
            if m:
                value = m.group(1)
                setattr(self, attr, value)
                if attr.upper() in Cell.Encryptions.__dict__:
                    self.encryption = attr
                elif attr == "signal":
                    self.signal_integer = float(value.split()[0])

    def __repr__(self):
        return "{}\t{}".format(self.essid, self.signal)

    @staticmethod
    def scan_essids(iface,
                    scan_attempts=7,
                    scan_results_filename="/tmp/wifi-scan-results",
                    debugging=False):
        "scan for available access points or cells"
        for _ in range(scan_attempts):
            iw_out = None
            if debugging:
                iw_out = open(scan_results_filename).read()
            else:
                p = subprocess.Popen(["sudo", "iw", "dev", iface, "scan"],
                                     stdout=subprocess.PIPE,
                                     stderr=subprocess.PIPE)
                stdout, stderr = p.communicate()
                if p.returncode == 0:
                    with open(scan_results_filename, "w") as fh:
                        print(stdout, file=fh)
                    iw_out = stdout
                else:
                    logger.error("error scanning: %s retrying...", stderr)
                    logger.info("retrying...")
                    time.sleep(1)
            if iw_out:
                cells_flat = re.split("\nBSS", iw_out)
                logging.info("found %s possible cells", len(cells_flat))
                if not cells_flat:
                    logger.info("no networks found. retrying...")
                    time.sleep(1)
                else:
                    cells = [Cell(scan_output=cell_flat) for cell_flat in cells_flat]
                    return cells
        raise Exception("scanning failed")

    def write_to_file(self, directory, password=None, force=False):
        if not os.path.exists(directory):
            os.makedirs(directory)
        essid_file = os.path.join(directory, self.essid)
        if not os.path.exists(essid_file) or force:
            if self.encryption and not password:
                password = getpass.getpass("enter password for {}: ".format(self.essid))
            with open(essid_file, "w") as fh:
                if self.is_wpa():
                    call_check(["wpa_passphrase", self.essid, password], stdout=fh)
                else:
                    print(password or "", file=fh)
        return essid_file

    def is_wpa(self):
        return self.encryption in (Cell.Encryptions.WPA, Cell.Encryptions.WPA2)

    def connect(self, essid_file):
        if self.is_wpa():
            pkill("wpa_supplicant")
            p=subprocess.Popen(["sudo", "wpa_supplicant",
                                "-i", self.iface, "-c", essid_file, "-D", "nl80211,wext"],
                               stdout=subprocess.PIPE)
            for line in iter(p.stdout.readline, ""):
                print (line)
                if "CTRL-EVENT-CONNECTED" in line:
                    break
                elif re.search("WRONG_KEY|Invalid configuration line", line):
                    raise Exception("failed to connect via wpa_supplicant")
            p.stdout.close()
        else:
            # wep or no encryption
            cmd = ["sudo", "iwconfig", self.iface, "essid", self.essid]
            if self.encryption == self.Encryptions.WEP:
                with open(essid_file, "r") as fh:
                    password = fh.read()
                cmd += ["enc", "WEP", "key", password]
            call_check(cmd)
        pkill("dhclient")
        call_check(["sudo", "dhclient", "-v", self.iface])

def select_cell(iface, essid=None, autoselect_essid=True, essids_directory=None):
    cells = Cell.scan_essids(iface=iface)
    if not cells:
        logging.error("no wifi access points found")
    else:
        known_essids = [essid] if essid else known_essids_list(essids_directory)
        matching = [cell for cell in cells if cell.essid in known_essids]
        # strongest first
        matching.sort(key=lambda cell: cell.signal_integer, reverse=True)
        print ("DEBUG wifi-connect ifga: value of matching: {}".format(
            "\n".join(map(str, matching))))
        if not matching:
            logging.error(
                "no wifi access points found with essids:\n%s\nfound:\n%s",
                ", ".join(known_essids),
                ", ".join(cell.essid or "NONE" for cell in cells))
        elif not autoselect_essid and len(matching) > 1:
            return selcand(matching)
        else:
            return matching[0]

def iface_down_up(iface, macchange_opt=None):
    if macchange_opt != None:
        call_check(["sudo", "ifconfig", iface, "down"])
        call_check(["sudo", "macchanger", "-{}".format(macchange_opt), iface])
    call_check(["sudo", "ifconfig", iface, "up"])

def wifi_connect(config) :
    "connect to one of the available wifi networks"
    pkill("wpa_supplicant")
    pkill("dhclient")

    if not config.iface:
        ifaces = iface_list()
        config.iface = selcand(ifaces, error="wireless iface not found")
    iface_down_up(iface=config.iface, macchange_opt=config.macchange_opt)
    cell = select_cell(iface=config.iface,
                       essid=config.essid,
                       autoselect_essid=not config.always_ask_essid,
                       essids_directory=config.essids_directory)
    assert cell, "no cell was selected"
    essid_file =cell.write_to_file(config.essids_directory,
                                   password=config.password,
                                   force=config.overwrite)
    cell.connect(essid_file)


def main():
    "main method"
    parser = argparse.ArgumentParser()
    parser.add_argument("-o", "--overwrite", action="store_true",
                        help="flag to disregard any existing password")
    parser.add_argument("-e", "--essid",
                        help="connect to given essid. required when connecting to a hidden essid")
    parser.add_argument("-p", "--password",
                        help="the password, option to avoid interactive prompt")
    parser.add_argument("-m", "--macchange-opt",
                        help="a one-character flag proxied to macchanger")
    parser.add_argument("-i", "--iface",
                        help="the wireless interface to use for discovery")
    parser.add_argument("-a", "--always-ask-essid", action="store_true",
                        help="always prompt for essid, even if matching entry exists")
    parser.add_argument("-E", "--encryption",
                        help="sets the network's encryption. "+
                        "required when connecting to a hidden essid")
    parser.add_argument("-d", "--essids_directory", default=
                        os.path.expanduser("~/.config/wifi-connect"))
    parser.add_argument("-v", "--verbose", action="store_true")

    args = parser.parse_args()

    if args.verbose or True:
        logger.setLevel(logging.DEBUG)
        logger.debug("verbose on...")
    del args.verbose

    wifi_connect(args)

if __name__ == "__main__":
    main()

# Local Variables:
# compile-command: "./wifi-connect.py -v"
# End:
