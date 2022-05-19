﻿# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

. $PSScriptRoot\..\StoreQuery\Get-MailboxIndexMessageStatistics.ps1
. $PSScriptRoot\Write-DisplayObjectInformation.ps1
function Write-MailboxIndexMessageStatistics {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [object]$BasicMailboxQueryContext,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [object]$MailboxStatistics,

        [Parameter(Mandatory = $true)]
        [ValidateSet("All", "Indexed", "PartiallyIndexed", "NotIndexed", "Corrupted", "Stale", "ShouldNotBeIndexed")]
        [string[]]$Category,

        [bool]$GroupMessages

    )

    process {
        $totalIndexableItems = ($MailboxStatistics.AssociatedItemCount + $MailboxStatistics.ItemCount + $MailboxStatistics.DeletedItemCount) - $MailboxStatistics.BigFunnelShouldNotBeIndexedCount

        Write-Host ""
        Write-Host "All Indexable Items Count: $totalIndexableItems"
        Write-Host ""

        foreach ($categoryType in $Category) {

            $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
            [array]$messages = Get-MailboxIndexMessageStatistics -BasicMailboxQueryContext $BasicMailboxQueryContext -Category $categoryType
            Write-Verbose "Took $($stopWatch.Elapsed.TotalSeconds) seconds to get the mailbox index message stats for $($messages.count) messages"

            if ($messages.Count -gt 0) {

                if (-not $GroupMessages) {

                    foreach ($message in $messages) {
                        Write-Host "---------------------"
                        Write-DisplayObjectInformation -DisplayObject $message -PropertyToDisplay @(
                            "MessageId",
                            "InternetMessageId",
                            "MessageSubject",
                            "BigFunnelPOISize",
                            "BigFunnelPOIIsUpToDate",
                            "IndexingErrorCode",
                            "IndexingErrorMessage",
                            "CondensedErrorMessage",
                            "ErrorTags",
                            "ErrorProperties",
                            "LastIndexingAttemptTime",
                            "IsPermanentFailure",
                            "IndexStatus"
                        )
                    }
                    continue
                }

                $groupedStatus = $messages | Group-Object IndexStatus

                foreach ($statusGrouping in $groupedStatus) {
                    Write-Host "---------------------"
                    Write-Host "Message Index Status: $($statusGrouping.Name)"
                    Write-Host "---------------------"
                    $groupedResults = $statusGrouping.Group |
                        Group-Object CondensedErrorMessage, IsPermanentFailure |
                        Sort-Object Count -Descending
                    foreach ($result in $groupedResults) {

                        $earliestLastIndexingAttemptTime = [DateTime]::MaxValue
                        $lastIndexingAttemptTime = [DateTime]::MinValue

                        foreach ($groupEntry in $groupedResults.Group) {

                            if ($groupEntry.LastIndexingAttemptTime -gt $lastIndexingAttemptTime) {
                                $lastIndexingAttemptTime = $groupEntry.LastIndexingAttemptTime
                            }

                            if ($groupEntry.LastIndexingAttemptTime -lt $earliestLastIndexingAttemptTime) {
                                $earliestLastIndexingAttemptTime = $groupEntry.LastIndexingAttemptTime
                            }
                        }

                        $obj = [PSCustomObject]@{
                            TotalItems                      = $result.Count
                            ErrorMessage                    = $result.Values[0]
                            IsPermanentFailure              = $result.Values[1]
                            EarliestLastIndexingAttemptTime = $earliestLastIndexingAttemptTime
                            LastIndexingAttemptTime         = $lastIndexingAttemptTime
                        }

                        Write-DisplayObjectInformation -DisplayObject $obj -PropertyToDisplay @(
                            "TotalItems",
                            "ErrorMessage",
                            "IsPermanentFailure",
                            "EarliestLastIndexingAttemptTime",
                            "LastIndexingAttemptTime")
                        Write-Host ""
                    }
                }
            } else {
                Write-Host "Failed to find any results when doing a search on the category $categoryType"
            }
        }
    }
}
