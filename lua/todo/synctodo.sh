#!/bin/bash

num_args=$#

DEFAULT_MAC_SMPOS="/tmp/reminders_SMPOS.txt"
DEFAULT_VAULT="/Users/lucas/zettelkasten"
DELIM="zettelkasten"

VAULT=${1:-$DEFAULT_VAULT}
MAC_SMPOS=${2:-$DEFAULT_MAC_SMPOS}



if ! command -v reminders &> /dev/null
then
    echo "Please install 'reminders' from https://github.com/keith/reminders-cli"
    exit
fi

if ! reminders show-lists |grep -q "SMPOS"; then
  echo "Please create 'SMPOS' list in Mac Reminders manually."
  exit
fi

reminders show SMPOS > $MAC_SMPOS

rg -N -e "^- \[[ ]\]" $VAULT|sed 's/- \[[ xX]\] //g' | while read -r line; 
do 
  list=`echo $line | awk -F'.md:' '{print $1}' | awk -F"$DELIM\/" '{print $NF}'`
  item=`echo $line | awk -F'.md:' '{print $2}'`
  item=`echo $item | sed 's/\[/【/g'|sed 's/\]/】/g'`
  if ! grep -q "^[0-9]*: $list:$item$" $MAC_SMPOS; then
    reminders add SMPOS "$list:$item"
  fi
done


rg -N -e "^- \[[xX]\]" $VAULT/|sed 's/- \[[ xX]\] //g' | while read -r line; 
do 
  list=`echo $line | awk -F'.md:' '{print $1}' | awk -F"$DELIM\/" '{print $NF}'`
  item=`echo $line | awk -F'.md:' '{print $2}'`
  item=`echo $item | sed 's/\[/【/g'|sed 's/\]/】/g'`
  grep "^[0-9]*: $list:$item$" $MAC_SMPOS | while read -r mac_line;
  do
    ID=`echo $mac_line | cut -d: -f1`
    reminders complete SMPOS $ID
  done
done



reminders show SMPOS > $MAC_SMPOS
cat $MAC_SMPOS |sed 's/^[0-9]*: //' | while read -r line; 
do
  list="Reminders"
  item="unknown"
  if [[ $line =~ [:] ]]; then
    list=`echo $line | sed 's/:.*//'`
    item=`echo $line | sed 's/^[^:]*://'`
    item=`echo $item | sed 's/【/\[/g'|sed 's/】/\]/g'`
  else
    list="Reminders"
    item=$line
  fi
  md=$VAULT/$list.md
  blank_patterned_item=`echo $item | sed 's/ / \*/g' |sed 's/\[/\\\[/g'|sed 's/\]/\\\]/g' `
  if ! grep -q "\- \[[ xX]\] $blank_patterned_item" "$md"; then
    echo "Add $item to $list.md"
    echo "- [ ] $item" >> "$md"
  fi
done


