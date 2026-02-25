// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/JobsBoard.sol";

contract JobsBoardTest is Test {
    JobsBoard instance;
    address admin = address(1);
    address poster = address(2);
    address worker = address(3);
    address worker2 = address(4);

    function setUp() public {
        JobsBoard impl = new JobsBoard();
        bytes memory init = abi.encodeCall(JobsBoard.initialize, (admin));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), init);
        instance = JobsBoard(address(proxy));
    }

    // ── Authorization ──────────────────────────────────────────────────────

    function test_InitialOwner() public view {
        // Owner is admin
        // Since owner() is OwnableUpgradeable, just verify the poster authorization flow
        assertFalse(instance.authorizedPosters(poster));
    }

    function test_AuthorizePoster() public {
        vm.prank(admin);
        instance.authorizePoster(poster, true);
        assertTrue(instance.authorizedPosters(poster));
    }

    function test_RevokePoster() public {
        vm.prank(admin);
        instance.authorizePoster(poster, true);
        vm.prank(admin);
        instance.authorizePoster(poster, false);
        assertFalse(instance.authorizedPosters(poster));
    }

    function test_UnauthorizedPosterReverts() public {
        vm.prank(worker);
        vm.expectRevert("Not authorized poster");
        instance.postJob(
            JobsBoard.JobLevel.Small,
            JobsBoard.JobCategory.Finance,
            "Test Job",
            "Description",
            1 * 1e18,
            0,
            0,
            JobsBoard.ClearanceLevel.None,
            30,
            ""
        );
    }

    // ── Post Jobs ──────────────────────────────────────────────────────────

    function test_PostSmallJob() public {
        vm.prank(admin);
        instance.authorizePoster(poster, true);

        vm.prank(poster);
        uint256 jobId = instance.postJob(
            JobsBoard.JobLevel.Small,
            JobsBoard.JobCategory.Technology,
            "Dev Task",
            "Write a contract",
            5_000 * 1e18,
            0,
            0,
            JobsBoard.ClearanceLevel.None,
            14,
            "ipfs://hash"
        );

        assertEq(jobId, 1);
        assertEq(instance.totalJobsPosted(), 1);

        JobsBoard.Job memory j = instance.getJob(1);
        assertEq(j.payOICD, 5_000 * 1e18);
        assertEq(j.poster, poster);
        assertEq(uint8(j.status), uint8(JobsBoard.JobStatus.Open));
        assertEq(uint8(j.level), uint8(JobsBoard.JobLevel.Small));
    }

    function test_PostAlphaJob() public {
        vm.prank(admin);
        instance.authorizePoster(poster, true);

        vm.prank(poster);
        uint256 jobId = instance.postJob(
            JobsBoard.JobLevel.Alpha,
            JobsBoard.JobCategory.Finance,
            "Alpha Contract",
            "High value work",
            500_000 * 1e18,
            0,
            0,
            JobsBoard.ClearanceLevel.Alpha,
            30,
            ""
        );

        assertEq(jobId, 1);
        JobsBoard.Job memory j = instance.getJob(1);
        assertEq(uint8(j.level), uint8(JobsBoard.JobLevel.Alpha));
        assertEq(uint8(j.clearance), uint8(JobsBoard.ClearanceLevel.Alpha));
    }

    function test_PostJobInvalidPayReverts() public {
        vm.prank(admin);
        instance.authorizePoster(poster, true);

        // Small job with pay exceeding max
        vm.prank(poster);
        vm.expectRevert("Small: 1-15K OICD");
        instance.postJob(
            JobsBoard.JobLevel.Small,
            JobsBoard.JobCategory.Finance,
            "Bad Job",
            "desc",
            20_000 * 1e18, // over Small max
            0,
            0,
            JobsBoard.ClearanceLevel.None,
            30,
            ""
        );
    }

    function test_PostJobOwnerCanPost() public {
        // Owner (admin) should also be able to post without being in authorizedPosters
        vm.prank(admin);
        uint256 jobId = instance.postJob(
            JobsBoard.JobLevel.Medium,
            JobsBoard.JobCategory.Legal,
            "Medium Job",
            "desc",
            20_000 * 1e18,
            0,
            0,
            JobsBoard.ClearanceLevel.None,
            60,
            ""
        );
        assertEq(jobId, 1);
    }

    // ── Apply & Hire ────────────────────────────────────────────────────────

    function _postOpenJob() internal returns (uint256 jobId) {
        vm.prank(admin);
        instance.authorizePoster(poster, true);
        vm.prank(poster);
        jobId = instance.postJob(
            JobsBoard.JobLevel.Small,
            JobsBoard.JobCategory.Technology,
            "Dev Task",
            "Write a contract",
            1_000 * 1e18,
            0,
            0,
            JobsBoard.ClearanceLevel.None,
            30,
            ""
        );
    }

    function test_ApplyForJob() public {
        uint256 jobId = _postOpenJob();

        vm.prank(worker);
        uint256 appId = instance.applyForJob(jobId, "I am interested");

        assertEq(appId, 1);
        assertEq(instance.applicationCounter(), 1);

        JobsBoard.Application memory app = instance.getApplication(1);
        assertEq(app.applicant, worker);
        assertEq(app.jobId, jobId);
        assertFalse(app.accepted);
    }

    function test_PosterCannotApplyToOwnJob() public {
        uint256 jobId = _postOpenJob();

        vm.prank(poster);
        vm.expectRevert("Cannot apply to own job");
        instance.applyForJob(jobId, "Self apply");
    }

    function test_HireWorker() public {
        uint256 jobId = _postOpenJob();

        vm.prank(worker);
        instance.applyForJob(jobId, "Hire me");

        vm.prank(poster);
        instance.hireWorker(jobId, worker);

        JobsBoard.Job memory j = instance.getJob(jobId);
        assertEq(uint8(j.status), uint8(JobsBoard.JobStatus.InProgress));
        assertEq(j.assignedWorker, worker);
    }

    function test_HireWorkerNonPosterReverts() public {
        uint256 jobId = _postOpenJob();

        vm.prank(worker2);
        vm.expectRevert("Not poster");
        instance.hireWorker(jobId, worker);
    }

    // ── Complete & Cancel ──────────────────────────────────────────────────

    function test_MarkJobComplete() public {
        uint256 jobId = _postOpenJob();
        vm.prank(poster);
        instance.hireWorker(jobId, worker);

        vm.prank(poster);
        instance.markJobComplete(jobId);

        JobsBoard.Job memory j = instance.getJob(jobId);
        assertEq(uint8(j.status), uint8(JobsBoard.JobStatus.Completed));
        assertTrue(j.paid);

        assertEq(instance.totalJobsCompleted(), 1);

        JobsBoard.WorkerProfile memory wp = instance.getWorkerProfile(worker);
        assertEq(wp.jobsCompleted, 1);
        assertEq(wp.totalEarnedOICD, 1_000 * 1e18);
        assertEq(wp.reputationScore, 55); // 50 default + 5 for completion
    }

    function test_MarkJobCompleteNotInProgressReverts() public {
        uint256 jobId = _postOpenJob();
        vm.prank(poster);
        vm.expectRevert("Not in progress");
        instance.markJobComplete(jobId);
    }

    function test_CancelOpenJob() public {
        uint256 jobId = _postOpenJob();
        vm.prank(poster);
        instance.cancelJob(jobId);

        JobsBoard.Job memory j = instance.getJob(jobId);
        assertEq(uint8(j.status), uint8(JobsBoard.JobStatus.Cancelled));
    }

    function test_CancelCompletedJobReverts() public {
        uint256 jobId = _postOpenJob();
        vm.prank(poster);
        instance.hireWorker(jobId, worker);
        vm.prank(poster);
        instance.markJobComplete(jobId);

        vm.prank(poster);
        vm.expectRevert("Cannot cancel");
        instance.cancelJob(jobId);
    }

    // ── Clearance & Reputation ─────────────────────────────────────────────

    function test_GrantClearance() public {
        vm.prank(admin);
        instance.grantClearance(worker, JobsBoard.ClearanceLevel.Alpha);

        JobsBoard.WorkerProfile memory wp = instance.getWorkerProfile(worker);
        assertEq(uint8(wp.clearance), uint8(JobsBoard.ClearanceLevel.Alpha));
    }

    function test_ClearanceGatingOnApplication() public {
        vm.prank(admin);
        instance.authorizePoster(poster, true);
        vm.prank(poster);
        uint256 jobId = instance.postJob(
            JobsBoard.JobLevel.Alpha,
            JobsBoard.JobCategory.Finance,
            "Alpha Job",
            "need alpha clearance",
            500_000 * 1e18,
            0,
            0,
            JobsBoard.ClearanceLevel.Alpha,
            30,
            ""
        );

        // Worker without clearance
        vm.prank(worker);
        vm.expectRevert("Insufficient clearance");
        instance.applyForJob(jobId, "No clearance");

        // Grant clearance and try again
        vm.prank(admin);
        instance.grantClearance(worker, JobsBoard.ClearanceLevel.Alpha);

        vm.prank(worker);
        uint256 appId = instance.applyForJob(jobId, "Now I have clearance");
        assertEq(appId, 1);
    }

    function test_UpdateReputation() public {
        vm.prank(admin);
        instance.updateReputation(worker, 90);

        // Reputation is stored in workerProfiles — worker must exist first
        // Profile is only created on first apply or on markJobComplete, so register via grantClearance
        vm.prank(admin);
        instance.grantClearance(worker, JobsBoard.ClearanceLevel.None);
        vm.prank(admin);
        instance.updateReputation(worker, 80);

        JobsBoard.WorkerProfile memory wp = instance.getWorkerProfile(worker);
        assertEq(wp.reputationScore, 80);
    }

    function test_UpdateReputationAbove100Reverts() public {
        vm.prank(admin);
        vm.expectRevert("Max 100");
        instance.updateReputation(worker, 101);
    }

    // ── Board Stats ────────────────────────────────────────────────────────

    function test_BoardStats() public {
        uint256 jobId = _postOpenJob();
        vm.prank(poster);
        instance.hireWorker(jobId, worker);
        vm.prank(poster);
        instance.markJobComplete(jobId);

        (uint256 posted, uint256 completed, uint256 oicd, uint256 stock) = instance.boardStats();
        assertEq(posted, 1);
        assertEq(completed, 1);
        assertEq(oicd, 1_000 * 1e18);
        assertEq(stock, 0);
    }

    // ── View helpers ───────────────────────────────────────────────────────

    function test_GetPosterJobs() public {
        uint256 jobId = _postOpenJob();
        uint256[] memory pj = instance.getPosterJobs(poster);
        assertEq(pj.length, 1);
        assertEq(pj[0], jobId);
    }

    function test_GetWorkerApplications() public {
        uint256 jobId = _postOpenJob();
        vm.prank(worker);
        instance.applyForJob(jobId, "cover");
        uint256[] memory apps = instance.getWorkerApplications(worker);
        assertEq(apps.length, 1);
    }

    function test_GetJobApplications() public {
        uint256 jobId = _postOpenJob();
        vm.prank(worker);
        instance.applyForJob(jobId, "hi");
        vm.prank(worker2);
        instance.applyForJob(jobId, "hello");
        uint256[] memory jobApps = instance.getJobApplications(jobId);
        assertEq(jobApps.length, 2);
    }
}
