import csv
with open("firewallsDC.csv",'w') as csvfile:
    w=csv.writer(csvfile, delimiter=',')
    w.writerow(["Name","Template","Cluster","Datastore","Customization","Location","CPU","RAM","HDD","DiskFormat","Network","IP","Subnet","Gateway","DNS"])
    for i in range(17):
        w.writerow(["FirewallClassTeamX".replace('X',str(i)),"SS_S20_FirewallsAttackVM","MAIN","THE-VAULT","$folder","2","8","40","Thin",'10.42.X.1/24'.replace('X', str(i)),
        '10.42.X.253'.replace('X', str(i)), '255.255.255.0', '10.42.X.1'.replace('X',str(i)), '8.8.8.8'])
        
    w.writerow(["FirewallClassTeam25","SS_S20_FirewallsAttackVM","MAIN","THE-VAULT","$folder","2","8","40","Thin",'10.42.25.1/24',
        '10.42.25.253', '255.255.255.0', '10.42.25.1', '8.8.8.8'])
       	

