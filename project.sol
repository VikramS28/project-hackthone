struct Job {
    address client;
    address freelancer;
    uint256 amount;
    bool isCompleted;
    bool isReleased;
    uint256 deadline;
    bytes32 verificationHash; // Hash of AI-verified profile data
}

struct Rating {
    uint256 score; // 1-5
    string comment;
}

mapping(uint256 => Job) public jobs;
mapping(address => Rating[]) public freelancerRatings;

event JobCreated(uint256 jobId, address client, address freelancer, uint256 amount, uint256 deadline);
event FundsReleased(uint256 jobId, address freelancer, uint256 amount);
event FundsRefunded(uint256 jobId, address client, uint256 amount);
event FreelancerRated(address freelancer, uint256 score, string comment);

// Create a new job
function createJob(address _freelancer, uint256 _deadline, bytes32 _verificationHash) external payable nonReentrant {
    require(msg.value > 0, "Deposit must be greater than 0");
    require(_freelancer != address(0), "Invalid freelancer address");
    require(_deadline > block.timestamp, "Deadline must be in the future");

    _jobIds.increment();
    uint256 jobId = _jobIds.current();

    jobs[jobId] = Job({
        client: msg.sender,
        freelancer: _freelancer,
        amount: msg.value,
        isCompleted: false,
        isReleased: false,
        deadline: _deadline,
        verificationHash: _verificationHash // AI verification result
    });

    emit JobCreated(jobId, msg.sender, _freelancer, msg.value, _deadline);
}

// Freelancer marks job as completed
function markCompleted(uint256 _jobId) external {
    Job storage job = jobs[_jobId];
    require(msg.sender == job.freelancer, "Only freelancer can mark completed");
    require(!job.isCompleted, "Job already completed");

    job.isCompleted = true;
}

// Client releases funds to freelancer
function releaseFunds(uint256 _jobId) external nonReentrant {
    Job storage job = jobs[_jobId];
    require(msg.sender == job.client, "Only client can release funds");
    require(job.isCompleted, "Job not completed");
    require(!job.isReleased, "Funds already released");

    job.isReleased = true;
    payable(job.freelancer).transfer(job.amount);

    emit FundsReleased(_jobId, job.freelancer, job.amount);
}

// Refund client if deadline passes and job isn't completed
function refund(uint256 _jobId) external nonReentrant {
    Job storage job = jobs[_jobId];
    require(msg.sender == job.client, "Only client can request refund");
    require(block.timestamp > job.deadline, "Deadline not passed");
    require(!job.isCompleted, "Job already completed");
    require(!job.isReleased, "Funds already released");

    job.isReleased = true;
    payable(job.client).transfer(job.amount);

    emit FundsRefunded(_jobId, job.client, job.amount);
}

// Rate freelancer
function rateFreelancer(address _freelancer, uint256 _score, string calldata _comment) external {
    require(_score >= 1 && _score <= 5, "Score must be between 1 and 5");
    freelancerRatings[_freelancer].push(Rating({
        score: _score,
        comment: _comment
    }));

    emit FreelancerRated(_freelancer, _score, _comment);
}

// Get freelancer's average rating
function getAverageRating(address _freelancer) external view returns (uint256) {
    Rating[] memory ratings = freelancerRatings[_freelancer];
    if (ratings.length == 0) return 0;

    uint256 totalScore = 0;
    for (uint256 i = 0; i < ratings.length; i++) {
        totalScore += ratings[i].score;
    }
    return totalScore / ratings.length;
}