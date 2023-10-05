# Test Scenario

To make sure that IPFS-Gateway-ACL works follow these steps to test:


1. Links returning 302:

200.txt: https://localhost/ipfs/QmeomffUNfmQy76CQGy9NdmqEnnHU9soCexBnGU3ezPHVH
test-origin.html: https://localhost/ipfs/QmehaF8p4i49LoFHgRyzAcAo49NJ9gsRT8yQKRhzj3HUGY
ipfs.tech: https://localhost/ipns/ipfs.tech
chixodo.xyz: https://localhost/ipns/chixodo.xyz
chixodo.xyz: https://localhost/ipns/k51qzi5uqu5dm4zjyjaj8kx7exji2bmz1cf4lzv6f0wxzsesl0bz91kw86j61b
wikipedia: https://localhost/ipns/en.wikipedia-on-ipfs.org

2. Links returning 200:

200.txt: https://bafybeihuvwfdxuyytwrk3ee64qiurvujhwggfhcbb57sy7r7vz22vxtzza.ipfs.localhost/
test-origin.html: https://bafybeihtc4r2faclqgvuaelbk4cbb6bfrkhf57eudk4fytzekozvpjbpoe.ipfs.localhost/
chixodo.xyz: https://chixodo-xyz.ipns.localhost/
chixodo.xyz: https://k51qzi5uqu5dm4zjyjaj8kx7exji2bmz1cf4lzv6f0wxzsesl0bz91kw86j61b.ipns.localhost/
wikipedia: https://en-wikipedia--on--ipfs-org.ipns.localhost

3. Links returning 403:

rick.mp4: https://localhost/ipfs/QmcniBv7UQ4gGPQQW2BwbD4ZZHzN3o3tPuNLZCbBchd1zh
rick.mp4: https://bafybeigwwctpv37xdcwacqxvekr6e4kaemqsrv34em6glkbiceo3fcy4si.ipfs.localhost/
ipfs.tech: https://ipfs-tech.ipns.localhost/