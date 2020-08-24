# A Privacy-Preserved Voting Protocol

by Peter Zhou and Xingkai Wang

## Participants
*  Voting initiator 
*  Voting authority
	* Trusted by other parties to keep ballot privacy and conduct tally timely
 * Voter  
	 * Represented by a blockchain account
	 *	Whose eligibility decided by his/her account’s properties (e.g., the account balance or some tag attached to the account by some smart contract)
    
## Notations
1. A voting question can contain $N$ choices and voters are allowed to pick (at most) $M\leq N$ of them.
2. Let $(G,g)$ be a pair such that $G$ denotes a finite cyclic group of prime order $q$ in which the Decisional Diffie-Hellman problem is intractable, and $g$ is a generator in $G$.
3.  Let $\mathcal{P}_i$ denote an eligible voter who selects $N$ random values $\{\alpha_i^n \xleftarrow{R} \mathbb{Z}_q^*\}_{n=1}^N$ as the private voting keys and casts ballot $\big\{v_i^n\in\{0,1\}\big\}_{n=1}^N$ where $v_i^n=1$ means the $n^{\mathrm{th}}$ choice is picked and vice versa.
4.  Let $\mathcal{A}$ denote the voting authority who selects  random value $k \xleftarrow{R}\mathbb{Z}_q^*$ as the private authentication key
5.  Let $\mathcal{I}$ denote the voting initiator

## Voting Process

### Voting initialization via the voting contract
1.  $\mathcal{I}$ sets $(N,M)$ and decides whether the ballot from any voter $\mathcal{P}_i$ must satisfy $\sum_{n=1}^N v_i^n = M$, or it simply allows $\sum_{n=1}^N v_i^n \leq M$
 2. $\mathcal{I}$ sets criteria for eligible voters
 3. $\mathcal{I}$ sets the voting period (when to start, end, tally and etc.)
 4. $\mathcal{A}$ generates $k$ and shares $g^k$

### Vote
1. $\mathcal{P}_i$  generates $\big\{\alpha_i^n \big\}_{n=1}^N$.
2. $\mathcal{P}_i$ computes $\big\{x_i^n = g^{\alpha_i^n},\, y_i^n=g^{k\alpha_i^n}g^{v_i^n}, \,\mathrm{ZKP}_i^n\big\}_{n=1}^N$ where $v_i^n\in\{0, 1\}$ is the choice, $\mathrm{ZKP}_i^n$ the zero-knowledge proof (ZKP) of the validity of $v_i^n$.
3. $\mathcal{P}_i$ computes $\mathrm{ZKP}_i$ which is the ZKP of validity of $\sum_n v_i^n$ (e.g., $\sum_n v_i^n=M$ or $\sum_n v_i^n\leq M$).
4. $\mathcal{P}_i$ submit $\big\{\{x_i^n, y_i^n,\mathrm{ZKP}_i^n\}_n, \mathrm{ZKP}_i\big\}$ to the voting contract.

The current vote will replace the previous one within the allowed voting period. Details of ZKPs can be found in Appendix.

### Tally
1.  $\mathcal{A}$ computes $\big\{X_n=(\prod_i x_i^n)^k, Y_n =\prod_i y_i^n\big\}_n$
2.  $\mathcal{A}$ computes $\big\{V_n=\sum_i v_i^n=\log_g Y_n/X_n\big\}_n$
3.  $\mathcal{A}$ computes $\big\{\mathrm{ZKP}_{\mathcal{A}}^{\,n}n\big\}$ where $\mathrm{ZKP}^{\,n}_\mathcal{A}$ proves the correctness of the tally of the $n^{\mathrm{th}}$ choice over all the audits
4.  $\mathcal{A}$ submit $\big\{X_n,V_n , \mathrm{ZKP}_{\mathcal{A}}^{\,n}\big\}_n$ to the voting contract

## Pros and Cons

### Pros
* Ballot privacy, that is, no one except the voting authority knows the ballot contents
* Ballot verifiable
	* Voters can verify the existence of their ballots.
	* Anyone can verify the validity of a recorded ballot.
	* Recorded ballots are immutable. 
* Tally results universally verifiable
	* Anyone can verify that all and only the valid ballots have been tallied.
	* Anyone can verify the correctness of the tally results.
* Voters are allowed to cast multiple times and any valid ballot will replace the previous valid ballot cast by the same voter.

### Cons
* The voting authority has to be trusted to keep ballot privacy and conduct timely tallying
* Ballots are not anonymous in a sense that every ballot is tied to a particular account.

## Appendix

### $\mathrm{ZKP}_i^n$ --- Proof of $v_i^n\in\{0, 1\}$

Here we drop subscript $i$ and superscript $n$ from $v_i^n$, $\alpha_i^n$ and $y_i^n$ for simplicity, 

If $v=0$, $y=g^{k\alpha}$. The prover randomly chooses $\{w,d_2,r_2\in_R\mathbb{Z}_q\}$ and calculates:

* $a_1=g^w$, $b_1=g^{wk}$, 
* $a_2=g^{r_2+d_2\alpha}$, $b_2=g^{d_2k\alpha+kr_2-d_2}$, 
* $c=H\big(\mathrm{addr}(\mathcal{P}_i),g^\alpha,y,a_1,a_2,b_1,b_2\big)$,
* $d_1=c-d_2$, $r_1=w-d_\alpha$.

If $v=1$, $y=g^{k\alpha+1}$. The prover randomly choose $\{w,d_1,r_1\in_R\mathbb{Z}_q\}$ and calculates:

* $a_1=g^{r_1+d_1\alpha}$, $b_1=g^{d_1k\alpha+d_1+kr_1}=y^{d_1}(g^k)^{r_1}$, 
* $a_2=g^w$, $b_2=g^{wk}$, 
* $c=H\big(\mathrm{addr}(\mathcal{P}_i),g^\alpha,y,a_1,a_2,b_1,b_2\big)$,
* $d_2=c-d_1$, $r_2=w-d_2\alpha$.

The prover submits $\{y,a_1,b_1,a_2,b_2,d_1,d_2,r_1,r_2\}$ as the proof. Any verifier ce the proof through checking whether the following equations hold:

* $d_1+d_2=c=H\big(\mathrm{addr}(\mathcal{P}_i),g^\alpha,y,a_1,a_2,b_1,b_2\big)$, 
* $a_1=g^{r_1+d_1\alpha}$
* $b_1=g^{kr_1}y^{d_1}$
* $a_2=g^{r_2+d_2\alpha}$
* $b_2=g^{kr_2}(y/g)^{d_2}$

### $\mathrm{ZKP}_{\mathcal{A}}^{\,n}$ --- Proof of the tally correctness
Let $h=\prod_i x_i^n$. Since $X_n=h^k$ and $Y_n=h^kg^{V_n}$, $\mathcal{A}$ proves the oedge ofIt is equivalent to prove $k = \log_h Y_n/g^{V_n} = \log_h X_n$. 

To do that, $\mathcal{A}$ 

1. generates a random value $\beta\xleftarrow{R}\mathbb{Z}_q$ and computes $t=h^\beta$.
2. computes $c=H\big(\mathrm{addr}(\mathcal{A}),h,X_n,t\big)$, and
3. computes $r=\beta-ck$ and submits $(t,r)$ as the proof.  

Verifier can check whether $t=h^r X_n^c$. 

### $\mathrm{ZKP}_i$ --- Proof of the validity of $\sum_n v_i^n$

Let $h=g^k$, $\alpha_i=\sum_n\alpha_i^n$ and $Y_i=\prod_n y_i^n$.  

If $\sum_n v_i^n=M$, it is equivalent to prove $\alpha_i=\log_{h}Y_i/g^M$ and can be done in the same way as $\mathrm{ZKP_{\mathcal{A}}^n}$.

If $\sum_n v_i^n\leq M$ is allowed, $\mathcal{P}_i$ needs to prove 

$\big[\alpha_i=\log_{h}Y_i/g^0\big] \vee \big[\alpha_i=\log_{h}Y_i/g^1\big] \vee\cdots\vee \big[\alpha_i=\log_{h}Y_i/g^M\big]$., 

which can be done using zk-snark.